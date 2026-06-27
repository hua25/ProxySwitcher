import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case chinese

    var title: String {
        switch self {
        case .system:
            return L10n.followSystem
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

enum L10n {
    private static let languagePreferenceKey = "appLanguage"

    static var language: AppLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: languagePreferenceKey),
                  let language = AppLanguage(rawValue: rawValue)
            else {
                return .system
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languagePreferenceKey)
        }
    }

    static var isChinese: Bool {
        switch language {
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("zh") == true
        case .english:
            return false
        case .chinese:
            return true
        }
    }

    static var languageMenu: String { isChinese ? "语言" : "Language" }
    static var followSystem: String { isChinese ? "跟随系统" : "Follow System" }
    static var applying: String { isChinese ? "正在应用..." : "Applying..." }
    static var systemProxyEnabled: String { isChinese ? "系统代理：已开启" : "System Proxy: Enabled" }
    static var systemProxyDisabled: String { isChinese ? "系统代理：已关闭" : "System Proxy: Disabled" }
    static var systemProxyMixed: String { isChinese ? "系统代理：不一致" : "System Proxy: Mixed" }
    static var systemProxyUnknown: String { isChinese ? "系统代理：未知" : "System Proxy: Unknown" }
    static var refreshing: String { isChinese ? "正在刷新..." : "Refreshing..." }
    static var networkServices: String { isChinese ? "网络服务" : "Network Services" }
    static var enableSystemProxy: String { isChinese ? "启用系统代理" : "Enable System Proxy" }
    static var disableSystemProxy: String { isChinese ? "关闭系统代理" : "Disable System Proxy" }
    static var refreshStatus: String { isChinese ? "刷新状态" : "Refresh Status" }
    static var configure: String { isChinese ? "配置..." : "Configure..." }
    static var terminal: String { isChinese ? "Terminal 代理" : "Terminal" }
    static var copyEnableCommand: String { isChinese ? "复制启用命令" : "Copy Enable Command" }
    static var copyDisableCommand: String { isChinese ? "复制关闭命令" : "Copy Disable Command" }
    static var quit: String { isChinese ? "退出 ProxySwitcher" : "Quit ProxySwitcher" }
    static var current: String { isChinese ? "当前" : "Current" }
    static var primaryService: String { isChinese ? "主网络服务" : "Primary Service" }
    static var saved: String { isChinese ? "保存配置" : "Saved" }
    static var matchesCurrent: String { isChinese ? "与当前一致" : "matches current" }
    static var differsFromCurrent: String { isChinese ? "与当前不同" : "differs from current" }
    static var mixedAcrossServices: String { isChinese ? "各网络服务不一致" : "Mixed across services" }
    static var unknown: String { isChinese ? "未知" : "Unknown" }
    static var proxyOff: String { isChinese ? "代理关闭" : "Proxy Off" }
    static var protocolOn: String { isChinese ? "开" : "On" }
    static var protocolOff: String { isChinese ? "关" : "Off" }
    static var serviceCountSuffix: String { isChinese ? "个网络服务" : "service(s)" }
    static var cancel: String { isChinese ? "取消" : "Cancel" }
    static var save: String { isChinese ? "保存" : "Save" }
    static var host: String { isChinese ? "主机" : "Host" }
    static var httpPort: String { isChinese ? "HTTP 端口" : "HTTP Port" }
    static var httpsPort: String { isChinese ? "HTTPS 端口" : "HTTPS Port" }
    static var socksPort: String { isChinese ? "SOCKS 端口" : "SOCKS Port" }
    static var savedMessage: String { isChinese ? "已保存。" : "Saved." }

    static func systemProxyError(_ message: String) -> String {
        isChinese ? "系统代理：错误 - \(message)" : "System Proxy: Error - \(message)"
    }

    static func portMustBeNumber(_ name: String) -> String {
        isChinese ? "\(name) 端口必须是数字。" : "\(name) port must be a number."
    }

    static func localizedValidationError(_ message: String) -> String {
        guard isChinese else {
            return message
        }

        switch message {
        case "Host cannot be empty.":
            return "主机不能为空。"
        case "Configure at least one proxy port.":
            return "至少需要配置一个代理端口。"
        case "HTTP port must be between 1 and 65535.":
            return "HTTP 端口必须在 1 到 65535 之间。"
        case "HTTPS port must be between 1 and 65535.":
            return "HTTPS 端口必须在 1 到 65535 之间。"
        case "SOCKS port must be between 1 and 65535.":
            return "SOCKS 端口必须在 1 到 65535 之间。"
        default:
            return message
        }
    }
}
