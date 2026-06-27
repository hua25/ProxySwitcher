import Foundation

public struct TerminalCommandGenerator {
    public init() {}

    public func enableCommand(for configuration: ProxyConfiguration) -> String {
        var assignments: [String] = []
        let host = configuration.normalizedHost

        if let port = configuration.httpPort {
            let url = "http://\(host):\(port)"
            assignments.append("export http_proxy=\(url)")
            assignments.append("export HTTP_PROXY=\(url)")
        }

        if let port = configuration.httpsPort {
            let url = "http://\(host):\(port)"
            assignments.append("export https_proxy=\(url)")
            assignments.append("export HTTPS_PROXY=\(url)")
        }

        if let port = configuration.socksPort {
            let url = "socks5://\(host):\(port)"
            assignments.append("export all_proxy=\(url)")
            assignments.append("export ALL_PROXY=\(url)")
        }

        return assignments.joined(separator: "\n")
    }

    public func disableCommand() -> String {
        "unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY"
    }
}
