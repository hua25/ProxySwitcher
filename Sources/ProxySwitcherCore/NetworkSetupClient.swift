import Foundation

public protocol NetworkSetupRunning {
    func run(arguments: [String]) throws -> String
}

public protocol CommandRunning {
    func run(executablePath: String, arguments: [String]) throws -> String
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(executablePath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NetworkSetupError.commandFailed(message.isEmpty ? outputText : message)
        }

        return outputText
    }
}

public struct ProcessNetworkSetupRunner: NetworkSetupRunning {
    public init() {}

    public func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combinedText = [outputText, errorText].joined(separator: "\n")

        if combinedText.localizedCaseInsensitiveContains("AuthorizationCreate() failed") {
            throw NetworkSetupError.commandFailed("networksetup could not access macOS authorization services.")
        }

        guard process.terminationStatus == 0 else {
            let message = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NetworkSetupError.commandFailed(message.isEmpty ? outputText : message)
        }

        return outputText
    }
}

public enum NetworkSetupError: LocalizedError {
    case commandFailed(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .parseFailed(let message):
            return message
        }
    }
}

public final class NetworkSetupClient {
    private let runner: NetworkSetupRunning
    private let commandRunner: CommandRunning

    public init(
        runner: NetworkSetupRunning = ProcessNetworkSetupRunner(),
        commandRunner: CommandRunning = ProcessCommandRunner()
    ) {
        self.runner = runner
        self.commandRunner = commandRunner
    }

    public func enabledNetworkServices() throws -> [String] {
        let output = try runner.run(arguments: ["-listallnetworkservices"])
        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty
                    && !line.lowercased().contains("asterisk")
                    && !line.hasPrefix("*")
            }
    }

    public func targetNetworkServices() throws -> [String] {
        let enabledServices = try enabledNetworkServices()
        guard let primaryService = try? primaryNetworkService(enabledServices: enabledServices),
              enabledServices.contains(primaryService)
        else {
            return enabledServices
        }
        return [primaryService]
    }

    public func snapshot(configuration: ProxyConfiguration) throws -> SystemProxySnapshot {
        let enabledServices = try enabledNetworkServices()
        let primaryService = try? primaryNetworkService(enabledServices: enabledServices)
        let services = try enabledServices.map { service in
            NetworkServiceProxyStatus(
                serviceName: service,
                http: try readEndpoint(service: service, arguments: ["-getwebproxy", service]),
                https: try readEndpoint(service: service, arguments: ["-getsecurewebproxy", service]),
                socks: try readEndpoint(service: service, arguments: ["-getsocksfirewallproxy", service])
            )
        }

        return SystemProxySnapshot(services: services, configuration: configuration, primaryServiceName: primaryService)
    }

    public func enable(configuration: ProxyConfiguration) throws {
        if let error = configuration.validationError() {
            throw NetworkSetupError.commandFailed(error)
        }

        for service in try targetNetworkServices() {
            if let port = configuration.httpPort {
                _ = try runner.run(arguments: ["-setwebproxy", service, configuration.normalizedHost, "\(port)"])
                _ = try runner.run(arguments: ["-setwebproxystate", service, "on"])
            } else {
                _ = try runner.run(arguments: ["-setwebproxystate", service, "off"])
            }

            if let port = configuration.httpsPort {
                _ = try runner.run(arguments: ["-setsecurewebproxy", service, configuration.normalizedHost, "\(port)"])
                _ = try runner.run(arguments: ["-setsecurewebproxystate", service, "on"])
            } else {
                _ = try runner.run(arguments: ["-setsecurewebproxystate", service, "off"])
            }

            if let port = configuration.socksPort {
                _ = try runner.run(arguments: ["-setsocksfirewallproxy", service, configuration.normalizedHost, "\(port)"])
                _ = try runner.run(arguments: ["-setsocksfirewallproxystate", service, "on"])
            } else {
                _ = try runner.run(arguments: ["-setsocksfirewallproxystate", service, "off"])
            }
        }
    }

    public func disable() throws {
        for service in try targetNetworkServices() {
            _ = try runner.run(arguments: ["-setwebproxystate", service, "off"])
            _ = try runner.run(arguments: ["-setsecurewebproxystate", service, "off"])
            _ = try runner.run(arguments: ["-setsocksfirewallproxystate", service, "off"])
        }
    }

    private func readEndpoint(service: String, arguments: [String]) throws -> ProxyEndpoint {
        let output = try runner.run(arguments: arguments)
        let values = Dictionary(uniqueKeysWithValues: output.split(separator: "\n").compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                return nil
            }
            return (
                parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        })

        guard let enabled = values["Enabled"] else {
            throw NetworkSetupError.parseFailed("Could not parse proxy state for \(service).")
        }

        return ProxyEndpoint(
            enabled: parseEnabled(enabled),
            server: values["Server"].flatMap { $0.isEmpty ? nil : $0 },
            port: values["Port"].flatMap(Int.init)
        )
    }

    private func parseEnabled(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "yes", "y", "true", "1", "on", "enabled":
            return true
        default:
            return false
        }
    }

    private func primaryNetworkService(enabledServices: [String]) throws -> String? {
        guard let defaultDevice = try defaultNetworkDevice() else {
            return nil
        }

        let output = try runner.run(arguments: ["-listallhardwareports"])
        guard let serviceName = networkServiceName(forDevice: defaultDevice, hardwarePortsOutput: output),
              enabledServices.contains(serviceName)
        else {
            return nil
        }
        return serviceName
    }

    private func defaultNetworkDevice() throws -> String? {
        let output = try commandRunner.run(executablePath: "/sbin/route", arguments: ["-n", "get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("interface:") else {
                continue
            }

            return trimmed
                .replacingOccurrences(of: "interface:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func networkServiceName(forDevice device: String, hardwarePortsOutput: String) -> String? {
        var currentHardwarePort: String?

        for line in hardwarePortsOutput.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("Hardware Port:") {
                currentHardwarePort = trimmed
                    .replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Device:") {
                let currentDevice = trimmed
                    .replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if currentDevice == device {
                    return currentHardwarePort
                }
            }
        }

        return nil
    }
}
