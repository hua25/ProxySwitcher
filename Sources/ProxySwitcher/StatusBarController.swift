import AppKit
import ProxySwitcherCore

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: ConfigurationStore
    private let networkSetup: NetworkSetupClient
    private let commandGenerator = TerminalCommandGenerator()
    private let refreshQueue = DispatchQueue(label: "local.proxyswitcher.status-refresh", qos: .userInitiated)

    private var configurationWindow: ConfigurationWindow?
    private var configuration: ProxyConfiguration
    private var lastSnapshot: SystemProxySnapshot?
    private var lastError: String?
    private var isRefreshing = false

    init(store: ConfigurationStore = ConfigurationStore(), networkSetup: NetworkSetupClient = NetworkSetupClient()) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.networkSetup = networkSetup
        self.configuration = store.load()
        super.init()

        configureStatusItem()
        refreshStatusInBackground()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "ProxySwitcher")
            button.imagePosition = .imageLeading
            button.title = ""
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func readStatus() -> (ProxyConfiguration, SystemProxySnapshot?, String?) {
        let loadedConfiguration = store.load()
        do {
            let snapshot = try networkSetup.snapshot(configuration: loadedConfiguration)
            return (loadedConfiguration, snapshot, nil)
        } catch {
            return (loadedConfiguration, nil, error.localizedDescription)
        }
    }

    private func refreshStatusInBackground(rebuildOpenMenu: Bool = false) {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        if rebuildOpenMenu, let menu = statusItem.menu {
            rebuildMenu(menu)
        }

        refreshQueue.async { [weak self] in
            guard let self else {
                return
            }

            let result = self.readStatus()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.configuration = result.0
                self.lastSnapshot = result.1
                self.lastError = result.2
                self.isRefreshing = false
                self.updateIcon()

                if rebuildOpenMenu, let menu = self.statusItem.menu {
                    self.rebuildMenu(menu)
                }
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else {
            return
        }

        let title: String
        switch currentState() {
        case .enabled:
            title = "On"
        case .disabled:
            title = "Off"
        case .mixed:
            title = "Mix"
        case .unknown:
            title = "?"
        case .error:
            title = "!"
        }

        button.title = " \(title)"
    }

    private func currentState() -> OverallProxyState {
        if let lastError {
            return .error(lastError)
        }
        return lastSnapshot?.overallState ?? .unknown
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let statusItem = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if isRefreshing {
            let refreshingItem = NSMenuItem(title: L10n.refreshing, action: nil, keyEquivalent: "")
            refreshingItem.isEnabled = false
            menu.addItem(refreshingItem)
        }

        if let detail = statusDetail() {
            let detailItem = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            menu.addItem(detailItem)
        }

        if let snapshot = lastSnapshot {
            let savedItem = NSMenuItem(title: savedConfigurationDetail(snapshot: snapshot), action: nil, keyEquivalent: "")
            savedItem.isEnabled = false
            menu.addItem(savedItem)

            let servicesMenu = NSMenu()
            for service in snapshot.services {
                let item = NSMenuItem(title: service.currentProxyDescription, action: nil, keyEquivalent: "")
                item.isEnabled = false
                servicesMenu.addItem(item)
            }
            let servicesItem = NSMenuItem(title: L10n.networkServices, action: nil, keyEquivalent: "")
            servicesItem.submenu = servicesMenu
            menu.addItem(servicesItem)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: L10n.enableSystemProxy, action: #selector(enableSystemProxy), keyEquivalent: "e"))
        menu.addItem(actionItem(title: L10n.disableSystemProxy, action: #selector(disableSystemProxy), keyEquivalent: "d"))
        menu.addItem(actionItem(title: L10n.refreshStatus, action: #selector(refreshFromMenu), keyEquivalent: "r"))

        menu.addItem(.separator())
        menu.addItem(actionItem(title: L10n.configure, action: #selector(openConfiguration), keyEquivalent: ","))
        menu.addItem(languageMenuItem())

        let terminalMenu = NSMenu()
        terminalMenu.addItem(actionItem(title: L10n.copyEnableCommand, action: #selector(copyTerminalEnableCommand), keyEquivalent: "c"))
        terminalMenu.addItem(actionItem(title: L10n.copyDisableCommand, action: #selector(copyTerminalDisableCommand), keyEquivalent: "u"))
        let terminalItem = NSMenuItem(title: L10n.terminal, action: nil, keyEquivalent: "")
        terminalItem.submenu = terminalMenu
        menu.addItem(terminalItem)

        menu.addItem(.separator())
        menu.addItem(actionItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q"))
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func languageMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = L10n.language == language ? .on : .off
            submenu.addItem(item)
        }

        let item = NSMenuItem(title: L10n.languageMenu, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func statusTitle() -> String {
        switch currentState() {
        case .enabled:
            return L10n.systemProxyEnabled
        case .disabled:
            return L10n.systemProxyDisabled
        case .mixed:
            return L10n.systemProxyMixed
        case .unknown:
            return L10n.systemProxyUnknown
        case .error(let message):
            return L10n.systemProxyError(message)
        }
    }

    private func statusDetail() -> String? {
        if let lastError {
            return lastError
        }

        guard let snapshot = lastSnapshot else {
            return nil
        }

        let serviceCount = snapshot.services.count
        let current: String
        if snapshot.overallState == .mixed {
            current = L10n.mixedAcrossServices
        } else {
            current = snapshot.services.first?.currentProxyEndpointsDescription ?? L10n.unknown
        }
        return "\(serviceCount) \(L10n.serviceCountSuffix), \(L10n.current): \(current)"
    }

    private func savedConfigurationDetail(snapshot: SystemProxySnapshot) -> String {
        let matchText = snapshot.allServicesMatchConfiguration ? L10n.matchesCurrent : L10n.differsFromCurrent
        return "\(L10n.saved): \(configuration.savedProxyDescription) (\(matchText))"
    }

    @objc private func refreshFromMenu() {
        refreshStatusInBackground(rebuildOpenMenu: true)
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        L10n.language = language
        if let menu = statusItem.menu {
            rebuildMenu(menu)
        }
    }

    @objc private func enableSystemProxy() {
        do {
            configuration = store.load()
            if let error = configuration.validationError() {
                showError(L10n.localizedValidationError(error))
                return
            }
            try networkSetup.enable(configuration: configuration)
            refreshStatusInBackground(rebuildOpenMenu: true)
        } catch {
            lastError = error.localizedDescription
            updateIcon()
            showError(error.localizedDescription)
        }
    }

    @objc private func disableSystemProxy() {
        do {
            try networkSetup.disable()
            refreshStatusInBackground(rebuildOpenMenu: true)
        } catch {
            lastError = error.localizedDescription
            updateIcon()
            showError(error.localizedDescription)
        }
    }

    @objc private func openConfiguration() {
        configuration = store.load()
        let window = ConfigurationWindow(configuration: configuration, store: store) { [weak self] in
            self?.refreshStatusInBackground(rebuildOpenMenu: true)
        }
        configurationWindow = window
        window.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func copyTerminalEnableCommand() {
        configuration = store.load()
        Clipboard.copy(commandGenerator.enableCommand(for: configuration))
    }

    @objc private func copyTerminalDisableCommand() {
        Clipboard.copy(commandGenerator.disableCommand())
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "ProxySwitcher"
        alert.informativeText = message
        alert.runModal()
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
        refreshStatusInBackground(rebuildOpenMenu: true)
    }
}

private extension ProxyConfiguration {
    var httpPortText: String {
        httpPort.map(String.init) ?? "-"
    }

    var httpsPortText: String {
        httpsPort.map(String.init) ?? "-"
    }

    var socksPortText: String {
        socksPort.map(String.init) ?? "-"
    }

    var savedProxyDescription: String {
        "\(normalizedHost) H:\(httpPortText) HTTPS:\(httpsPortText) S:\(socksPortText)"
    }
}

private extension NetworkServiceProxyStatus {
    var currentProxyDescription: String {
        "\(serviceName): \(currentProxyEndpointsDescription)"
    }

    var currentProxyEndpointsDescription: String {
        let endpoints = [
            endpointDescription(name: "HTTP", endpoint: http),
            endpointDescription(name: "HTTPS", endpoint: https),
            endpointDescription(name: "SOCKS", endpoint: socks)
        ].filter { !$0.isEmpty }

        if endpoints.isEmpty {
            return L10n.off
        }

        return endpoints.joined(separator: ", ")
    }

    func endpointDescription(name: String, endpoint: ProxyEndpoint) -> String {
        guard endpoint.enabled else {
            return ""
        }

        let server = endpoint.server ?? "-"
        let port = endpoint.port.map(String.init) ?? "-"
        return "\(name) \(server):\(port)"
    }
}
