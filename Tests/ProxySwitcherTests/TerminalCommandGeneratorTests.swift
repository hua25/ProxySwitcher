import XCTest
@testable import ProxySwitcherCore

final class TerminalCommandGeneratorTests: XCTestCase {
    func testGeneratesEnableCommandForConfiguredProtocols() {
        let configuration = ProxyConfiguration(host: "127.0.0.1", httpPort: 7890, httpsPort: nil, socksPort: 7891)
        let command = TerminalCommandGenerator().enableCommand(for: configuration)

        XCTAssertTrue(command.contains("export http_proxy=http://127.0.0.1:7890"))
        XCTAssertTrue(command.contains("export HTTP_PROXY=http://127.0.0.1:7890"))
        XCTAssertFalse(command.contains("https_proxy"))
        XCTAssertTrue(command.contains("export all_proxy=socks5://127.0.0.1:7891"))
        XCTAssertTrue(command.contains("export ALL_PROXY=socks5://127.0.0.1:7891"))
    }

    func testGeneratesDisableCommandForCommonVariables() {
        let command = TerminalCommandGenerator().disableCommand()

        XCTAssertEqual(command, "unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY")
    }
}
