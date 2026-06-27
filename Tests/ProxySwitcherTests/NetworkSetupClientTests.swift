import XCTest
@testable import ProxySwitcherCore

private final class StubNetworkSetupRunner: NetworkSetupRunning {
    var responses: [[String]: String]
    private(set) var calls: [[String]] = []

    init(responses: [[String]: String]) {
        self.responses = responses
    }

    func run(arguments: [String]) throws -> String {
        calls.append(arguments)
        if let response = responses[arguments] {
            return response
        }
        return ""
    }
}

final class NetworkSetupClientTests: XCTestCase {
    func testReadsOnlyEnabledNetworkServices() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: """
            An asterisk (*) denotes that a network service is disabled.
            Wi-Fi
            *Thunderbolt Bridge
            USB 10/100/1000 LAN
            """
        ])
        let client = NetworkSetupClient(runner: runner)

        XCTAssertEqual(try client.enabledNetworkServices(), ["Wi-Fi", "USB 10/100/1000 LAN"])
    }

    func testParsesSnapshot() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\n",
            ["-getwebproxy", "Wi-Fi"]: "Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsecurewebproxy", "Wi-Fi"]: "Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsocksfirewallproxy", "Wi-Fi"]: "Enabled: No\nServer: \nPort: 0\n"
        ])
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: 7890, socksPort: nil)
        let client = NetworkSetupClient(runner: runner)
        let snapshot = try client.snapshot(configuration: configuration)

        XCTAssertEqual(snapshot.services.count, 1)
        XCTAssertEqual(snapshot.overallState, .enabled)
    }

    func testEnablesConfiguredProtocolsAndDisablesMissingOnes() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\n"
        ])
        let client = NetworkSetupClient(runner: runner)
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: 7891)

        try client.enable(configuration: configuration)

        XCTAssertTrue(runner.calls.contains(["-setwebproxy", "Wi-Fi", "127.0.0.1", "7890"]))
        XCTAssertTrue(runner.calls.contains(["-setwebproxystate", "Wi-Fi", "on"]))
        XCTAssertTrue(runner.calls.contains(["-setsecurewebproxystate", "Wi-Fi", "off"]))
        XCTAssertTrue(runner.calls.contains(["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "7891"]))
        XCTAssertTrue(runner.calls.contains(["-setsocksfirewallproxystate", "Wi-Fi", "on"]))
    }
}
