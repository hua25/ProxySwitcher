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

private final class StubCommandRunner: CommandRunning {
    var responses: [[String]: String]

    init(responses: [[String]: String] = [:]) {
        self.responses = responses
    }

    func run(executablePath: String, arguments: [String]) throws -> String {
        responses[[executablePath] + arguments] ?? ""
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
            ["-listallnetworkservices"]: "Wi-Fi\nUSB 10/100/1000 LAN\n",
            ["-listallhardwareports"]: "Hardware Port: Wi-Fi\nDevice: en0\nEthernet Address: 00:00:00:00:00:00\n",
            ["-getwebproxy", "Wi-Fi"]: "Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsecurewebproxy", "Wi-Fi"]: "Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsocksfirewallproxy", "Wi-Fi"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getwebproxy", "USB 10/100/1000 LAN"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getsecurewebproxy", "USB 10/100/1000 LAN"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getsocksfirewallproxy", "USB 10/100/1000 LAN"]: "Enabled: No\nServer: \nPort: 0\n"
        ])
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: 7890, socksPort: nil)
        let commandRunner = StubCommandRunner(responses: [
            ["/sbin/route", "-n", "get", "default"]: "interface: en0\n"
        ])
        let client = NetworkSetupClient(runner: runner, commandRunner: commandRunner)
        let snapshot = try client.snapshot(configuration: configuration)

        XCTAssertEqual(snapshot.services.count, 2)
        XCTAssertEqual(snapshot.primaryService?.serviceName, "Wi-Fi")
        XCTAssertEqual(snapshot.overallState, .enabled)
    }

    func testSnapshotDisplaysAllServicesButStateFollowsPrimaryService() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\nUSB 10/100/1000 LAN\n",
            ["-listallhardwareports"]: "Hardware Port: Wi-Fi\nDevice: en0\n",
            ["-getwebproxy", "Wi-Fi"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getsecurewebproxy", "Wi-Fi"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getsocksfirewallproxy", "Wi-Fi"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getwebproxy", "USB 10/100/1000 LAN"]: "Enabled: Yes\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsecurewebproxy", "USB 10/100/1000 LAN"]: "Enabled: No\nServer: \nPort: 0\n",
            ["-getsocksfirewallproxy", "USB 10/100/1000 LAN"]: "Enabled: No\nServer: \nPort: 0\n"
        ])
        let commandRunner = StubCommandRunner(responses: [
            ["/sbin/route", "-n", "get", "default"]: "interface: en0\n"
        ])
        let client = NetworkSetupClient(runner: runner, commandRunner: commandRunner)
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: nil)
        let snapshot = try client.snapshot(configuration: configuration)

        XCTAssertEqual(snapshot.services.count, 2)
        XCTAssertEqual(snapshot.primaryService?.serviceName, "Wi-Fi")
        XCTAssertEqual(snapshot.overallState, .disabled)
    }

    func testParsesNumericEnabledValues() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\nUSB 10/100/1000 LAN\n",
            ["-listallhardwareports"]: "Hardware Port: Wi-Fi\nDevice: en0\n",
            ["-getwebproxy", "Wi-Fi"]: "Enabled: 1\nServer: 127.0.0.1\nPort: 7890\n",
            ["-getsecurewebproxy", "Wi-Fi"]: "Enabled: 0\nServer: \nPort: 0\n",
            ["-getsocksfirewallproxy", "Wi-Fi"]: "Enabled: 0\nServer: \nPort: 0\n",
            ["-getwebproxy", "USB 10/100/1000 LAN"]: "Enabled: 1\nServer: 127.0.0.1\nPort: 8080\n",
            ["-getsecurewebproxy", "USB 10/100/1000 LAN"]: "Enabled: 0\nServer: \nPort: 0\n",
            ["-getsocksfirewallproxy", "USB 10/100/1000 LAN"]: "Enabled: 0\nServer: \nPort: 0\n"
        ])
        let commandRunner = StubCommandRunner(responses: [
            ["/sbin/route", "-n", "get", "default"]: "interface: en0\n"
        ])
        let client = NetworkSetupClient(runner: runner, commandRunner: commandRunner)
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: nil)
        let snapshot = try client.snapshot(configuration: configuration)

        XCTAssertTrue(snapshot.services[0].http.enabled)
        XCTAssertTrue(snapshot.services[1].http.enabled)
        XCTAssertEqual(snapshot.overallState, .enabled)
    }

    func testEnablesConfiguredProtocolsAndDisablesMissingOnes() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\nUSB 10/100/1000 LAN\n",
            ["-listallhardwareports"]: """
            Hardware Port: Wi-Fi
            Device: en0
            Ethernet Address: 00:00:00:00:00:00

            Hardware Port: USB 10/100/1000 LAN
            Device: en7
            Ethernet Address: 00:00:00:00:00:01
            """
        ])
        let commandRunner = StubCommandRunner(responses: [
            ["/sbin/route", "-n", "get", "default"]: "interface: en0\n"
        ])
        let client = NetworkSetupClient(runner: runner, commandRunner: commandRunner)
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: 7891)

        try client.enable(configuration: configuration)

        XCTAssertTrue(runner.calls.contains(["-setwebproxy", "Wi-Fi", "127.0.0.1", "7890"]))
        XCTAssertTrue(runner.calls.contains(["-setwebproxystate", "Wi-Fi", "on"]))
        XCTAssertTrue(runner.calls.contains(["-setsecurewebproxystate", "Wi-Fi", "off"]))
        XCTAssertTrue(runner.calls.contains(["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "7891"]))
        XCTAssertTrue(runner.calls.contains(["-setsocksfirewallproxystate", "Wi-Fi", "on"]))
        XCTAssertFalse(runner.calls.contains(["-setwebproxy", "USB 10/100/1000 LAN", "127.0.0.1", "7890"]))
    }

    func testFallsBackToEnabledServicesWhenPrimaryServiceCannotBeResolved() throws {
        let runner = StubNetworkSetupRunner(responses: [
            ["-listallnetworkservices"]: "Wi-Fi\nUSB 10/100/1000 LAN\n"
        ])
        let client = NetworkSetupClient(runner: runner, commandRunner: StubCommandRunner())

        XCTAssertEqual(try client.targetNetworkServices(), ["Wi-Fi", "USB 10/100/1000 LAN"])
    }
}
