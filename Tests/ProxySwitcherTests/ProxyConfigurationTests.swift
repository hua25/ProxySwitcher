import XCTest
@testable import ProxySwitcherCore

final class ProxyConfigurationTests: XCTestCase {
    func testValidatesHostAndPorts() {
        XCTAssertNotNil(ProxyConfiguration(host: "", httpPort: 7890, httpsPort: nil, socksPort: nil).validationError())
        XCTAssertNotNil(ProxyConfiguration(host: "127.0.0.1", httpPort: nil, httpsPort: nil, socksPort: nil).validationError())
        XCTAssertNotNil(ProxyConfiguration(host: "127.0.0.1", httpPort: 0, httpsPort: nil, socksPort: nil).validationError())
        XCTAssertNotNil(ProxyConfiguration(host: "127.0.0.1", httpPort: 65_536, httpsPort: nil, socksPort: nil).validationError())
        XCTAssertNil(ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: nil).validationError())
    }

    func testDetectsMatchingSystemState() {
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: 7890, socksPort: 7891)
        let service = NetworkServiceProxyStatus(
            serviceName: "Wi-Fi",
            http: ProxyEndpoint(enabled: true, server: "127.0.0.1", port: 7890),
            https: ProxyEndpoint(enabled: true, server: "127.0.0.1", port: 7890),
            socks: ProxyEndpoint(enabled: true, server: "127.0.0.1", port: 7891)
        )

        XCTAssertTrue(service.matches(configuration))
        XCTAssertEqual(SystemProxySnapshot(services: [service], configuration: configuration).overallState, .enabled)
        XCTAssertTrue(SystemProxySnapshot(services: [service], configuration: configuration).allServicesMatchConfiguration)
    }

    func testEnabledStateDoesNotRequireSavedConfigurationMatch() {
        let savedConfiguration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: nil)
        let service = NetworkServiceProxyStatus(
            serviceName: "Wi-Fi",
            http: ProxyEndpoint(enabled: true, server: "127.0.0.1", port: 8080),
            https: ProxyEndpoint(enabled: false, server: nil, port: nil),
            socks: ProxyEndpoint(enabled: false, server: nil, port: nil)
        )
        let snapshot = SystemProxySnapshot(services: [service], configuration: savedConfiguration)

        XCTAssertEqual(snapshot.overallState, .enabled)
        XCTAssertFalse(snapshot.allServicesMatchConfiguration)
    }

    func testStateUsesPrimaryServiceWhenServicesDisagree() {
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: nil)
        let wifi = NetworkServiceProxyStatus(
            serviceName: "Wi-Fi",
            http: ProxyEndpoint(enabled: true, server: "127.0.0.1", port: 7890),
            https: ProxyEndpoint(enabled: false, server: nil, port: nil),
            socks: ProxyEndpoint(enabled: false, server: nil, port: nil)
        )
        let ethernet = NetworkServiceProxyStatus(
            serviceName: "Ethernet",
            http: ProxyEndpoint(enabled: false, server: nil, port: nil),
            https: ProxyEndpoint(enabled: false, server: nil, port: nil),
            socks: ProxyEndpoint(enabled: false, server: nil, port: nil)
        )

        let snapshot = SystemProxySnapshot(services: [wifi, ethernet], configuration: configuration, primaryServiceName: "Ethernet")

        XCTAssertEqual(snapshot.overallState, .disabled)
        XCTAssertEqual(snapshot.primaryService?.serviceName, "Ethernet")
    }
}
