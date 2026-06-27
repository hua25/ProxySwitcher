import Foundation

public final class ConfigurationStore {
    private let defaults: UserDefaults
    private let key = "proxyConfiguration"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ProxyConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(ProxyConfiguration.self, from: data)
        else {
            return .defaultConfiguration
        }

        return configuration
    }

    public func save(_ configuration: ProxyConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: key)
    }
}
