import Foundation

public protocol NetworkSetupRunning {
    func run(arguments: [String]) throws -> String
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

    public init(runner: NetworkSetupRunning = ProcessNetworkSetupRunner()) {
        self.runner = runner
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

    public func snapshot(configuration: ProxyConfiguration) throws -> SystemProxySnapshot {
        let services = try enabledNetworkServices().map { service in
            NetworkServiceProxyStatus(
                serviceName: service,
                http: try readEndpoint(service: service, arguments: ["-getwebproxy", service]),
                https: try readEndpoint(service: service, arguments: ["-getsecurewebproxy", service]),
                socks: try readEndpoint(service: service, arguments: ["-getsocksfirewallproxy", service])
            )
        }

        return SystemProxySnapshot(services: services, configuration: configuration)
    }

    public func enable(configuration: ProxyConfiguration) throws {
        if let error = configuration.validationError() {
            throw NetworkSetupError.commandFailed(error)
        }

        for service in try enabledNetworkServices() {
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
        for service in try enabledNetworkServices() {
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
            enabled: enabled.caseInsensitiveCompare("Yes") == .orderedSame,
            server: values["Server"].flatMap { $0.isEmpty ? nil : $0 },
            port: values["Port"].flatMap(Int.init)
        )
    }
}
