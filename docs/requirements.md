# ProxySwitcher Requirements

## Summary

ProxySwitcher is a lightweight macOS menu bar tool for quickly viewing and switching system proxy settings and copying Terminal proxy commands.

## Requirements

- Run as a menu bar app without a main desktop window.
- Store one local proxy configuration with host, HTTP port, HTTPS port, and SOCKS port.
- Validate host and port input before applying changes.
- Read current system proxy state for enabled macOS network services.
- Enable configured HTTP, HTTPS, and SOCKS proxies across enabled network services.
- Disable HTTP, HTTPS, and SOCKS proxies across enabled network services.
- Generate Terminal enable and disable commands without modifying shell configuration files.
- Avoid high-frequency polling; refresh status when opening the menu, manually refreshing, or applying changes.

## Out of Scope

- Proxy credentials.
- PAC files.
- Bypass lists.
- Multiple proxy profiles.
- Importing Clash, Surge, sing-box, or other proxy app configuration.
- Mac App Store sandbox support.
