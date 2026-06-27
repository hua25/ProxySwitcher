import AppKit
import ProxySwitcherCore

final class ConfigurationWindow: NSWindowController {
    private let store: ConfigurationStore
    private let onSave: () -> Void
    private var configuration: ProxyConfiguration

    private let hostField = NSTextField()
    private let httpField = NSTextField()
    private let httpsField = NSTextField()
    private let socksField = NSTextField()
    private let messageLabel = NSTextField(labelWithString: "")

    init(configuration: ProxyConfiguration, store: ConfigurationStore, onSave: @escaping () -> Void) {
        self.configuration = configuration
        self.store = store
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.configure
        window.isReleasedWhenClosed = false
        let frameAutosaveName = "ProxySwitcherConfigurationWindow"
        window.setFrameAutosaveName(frameAutosaveName)
        if UserDefaults.standard.string(forKey: "NSWindow Frame \(frameAutosaveName)") == nil {
            window.center()
        }
        super.init(window: window)
        buildContent()
        loadFields()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        hostField.placeholderString = "127.0.0.1"
        httpField.placeholderString = "7890"
        httpsField.placeholderString = "7890"
        socksField.placeholderString = "7891"

        messageLabel.textColor = .secondaryLabelColor
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2

        stack.addArrangedSubview(row(label: L10n.host, field: hostField))
        stack.addArrangedSubview(row(label: L10n.httpPort, field: httpField))
        stack.addArrangedSubview(row(label: L10n.httpsPort, field: httpsField))
        stack.addArrangedSubview(row(label: L10n.socksPort, field: socksField))
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(buttonRow())

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func row(label: String, field: NSTextField) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 88).isActive = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let row = NSStackView(views: [labelView, field])
        row.orientation = .horizontal
        row.spacing = 10
        return row
    }

    private func buttonRow() -> NSStackView {
        let cancelButton = NSButton(title: L10n.cancel, target: self, action: #selector(cancel))
        let saveButton = NSButton(title: L10n.save, target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [spacer, cancelButton, saveButton])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func loadFields() {
        hostField.stringValue = configuration.host
        httpField.stringValue = configuration.httpPort.map(String.init) ?? ""
        httpsField.stringValue = configuration.httpsPort.map(String.init) ?? ""
        socksField.stringValue = configuration.socksPort.map(String.init) ?? ""
    }

    @objc private func cancel() {
        close()
    }

    @objc private func save() {
        let parsedPorts: (http: Int?, https: Int?, socks: Int?)
        do {
            parsedPorts = (
                try parsePort(httpField.stringValue, name: "HTTP"),
                try parsePort(httpsField.stringValue, name: "HTTPS"),
                try parsePort(socksField.stringValue, name: "SOCKS")
            )
        } catch {
            messageLabel.textColor = .systemRed
            messageLabel.stringValue = error.localizedDescription
            return
        }

        let updated = ProxyConfiguration(
            host: hostField.stringValue,
            httpPort: parsedPorts.http,
            httpsPort: parsedPorts.https,
            socksPort: parsedPorts.socks
        )

        if let error = updated.validationError() {
            messageLabel.textColor = .systemRed
            messageLabel.stringValue = L10n.localizedValidationError(error)
            return
        }

        do {
            try store.save(updated)
            configuration = updated
            messageLabel.textColor = .secondaryLabelColor
            messageLabel.stringValue = L10n.savedMessage
            onSave()
            close()
        } catch {
            messageLabel.textColor = .systemRed
            messageLabel.stringValue = error.localizedDescription
        }
    }

    private func parsePort(_ value: String, name: String) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard let port = Int(trimmed) else {
            throw ConfigurationWindowError.invalidPort(L10n.portMustBeNumber(name))
        }
        return port
    }
}

private enum ConfigurationWindowError: LocalizedError {
    case invalidPort(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let message):
            return message
        }
    }
}
