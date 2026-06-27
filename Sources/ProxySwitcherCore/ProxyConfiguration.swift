import Foundation

public struct ProxyConfiguration: Codable, Equatable {
    public var host: String
    public var httpPort: Int?
    public var httpsPort: Int?
    public var socksPort: Int?

    public static let defaultConfiguration = ProxyConfiguration(
        host: "127.0.0.1",
        httpPort: 7890,
        httpsPort: 7890,
        socksPort: 7891
    )

    public init(host: String, httpPort: Int?, httpsPort: Int?, socksPort: Int?) {
        self.host = host
        self.httpPort = httpPort
        self.httpsPort = httpsPort
        self.socksPort = socksPort
    }

    public var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var enabledProtocols: [ProxyProtocol] {
        var protocols: [ProxyProtocol] = []
        if httpPort != nil {
            protocols.append(.http)
        }
        if httpsPort != nil {
            protocols.append(.https)
        }
        if socksPort != nil {
            protocols.append(.socks)
        }
        return protocols
    }

    public func validationError() -> String? {
        if normalizedHost.isEmpty {
            return "Host cannot be empty."
        }

        let ports = [
            ("HTTP", httpPort),
            ("HTTPS", httpsPort),
            ("SOCKS", socksPort)
        ]

        if ports.allSatisfy({ $0.1 == nil }) {
            return "Configure at least one proxy port."
        }

        for (name, port) in ports {
            if let port, !(1...65_535).contains(port) {
                return "\(name) port must be between 1 and 65535."
            }
        }

        return nil
    }
}

public enum ProxyProtocol: String, CaseIterable, Codable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks = "SOCKS"
}

public struct ProxyEndpoint: Equatable {
    public var enabled: Bool
    public var server: String?
    public var port: Int?

    public init(enabled: Bool, server: String?, port: Int?) {
        self.enabled = enabled
        self.server = server
        self.port = port
    }
}

public struct EnabledProxySignature: Equatable {
    public var http: ProxyEndpoint?
    public var https: ProxyEndpoint?
    public var socks: ProxyEndpoint?
}

public struct NetworkServiceProxyStatus: Equatable {
    public var serviceName: String
    public var http: ProxyEndpoint
    public var https: ProxyEndpoint
    public var socks: ProxyEndpoint

    public init(serviceName: String, http: ProxyEndpoint, https: ProxyEndpoint, socks: ProxyEndpoint) {
        self.serviceName = serviceName
        self.http = http
        self.https = https
        self.socks = socks
    }

    public func matches(_ configuration: ProxyConfiguration) -> Bool {
        endpoint(.http).matches(configuration: configuration, protocol: .http)
            && endpoint(.https).matches(configuration: configuration, protocol: .https)
            && endpoint(.socks).matches(configuration: configuration, protocol: .socks)
    }

    public func hasAnyEnabledProxy() -> Bool {
        http.enabled || https.enabled || socks.enabled
    }

    public var enabledProxySignature: EnabledProxySignature {
        EnabledProxySignature(
            http: http.enabled ? http : nil,
            https: https.enabled ? https : nil,
            socks: socks.enabled ? socks : nil
        )
    }

    public func endpoint(_ proxyProtocol: ProxyProtocol) -> ProxyEndpoint {
        switch proxyProtocol {
        case .http:
            return http
        case .https:
            return https
        case .socks:
            return socks
        }
    }
}

extension ProxyEndpoint {
    public func matches(configuration: ProxyConfiguration, protocol proxyProtocol: ProxyProtocol) -> Bool {
        let expectedPort: Int?
        switch proxyProtocol {
        case .http:
            expectedPort = configuration.httpPort
        case .https:
            expectedPort = configuration.httpsPort
        case .socks:
            expectedPort = configuration.socksPort
        }

        guard let expectedPort else {
            return !enabled
        }

        return enabled
            && server == configuration.normalizedHost
            && port == expectedPort
    }
}

public enum OverallProxyState: Equatable {
    case unknown
    case disabled
    case enabled
    case mixed
    case error(String)
}

public struct SystemProxySnapshot: Equatable {
    public var services: [NetworkServiceProxyStatus]
    public var configuration: ProxyConfiguration

    public init(services: [NetworkServiceProxyStatus], configuration: ProxyConfiguration) {
        self.services = services
        self.configuration = configuration
    }

    public var overallState: OverallProxyState {
        guard !services.isEmpty else {
            return .unknown
        }

        let disabledCount = services.filter { !$0.hasAnyEnabledProxy() }.count
        if disabledCount == services.count {
            return .disabled
        }

        let signatures = services.map(\.enabledProxySignature)
        if signatures.dropFirst().allSatisfy({ $0 == signatures[0] }) {
            return .enabled
        } else {
            return .mixed
        }
    }

    public var allServicesMatchConfiguration: Bool {
        !services.isEmpty && services.allSatisfy { $0.matches(configuration) }
    }
}
