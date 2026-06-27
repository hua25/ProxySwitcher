# ProxySwitcher

ProxySwitcher is a lightweight macOS menu bar app for checking and switching system proxy settings and copying Terminal proxy commands.

## Features

- Menu bar resident AppKit app.
- Stores one local proxy configuration.
- Supports HTTP, HTTPS, and SOCKS system proxy settings.
- Shows proxy settings for all enabled macOS network services.
- Applies system proxy changes to the current primary macOS network service when it can be detected.
- Copies Terminal `export` and `unset` commands without editing shell startup files.
- Supports English, Chinese, and following the system language.

## Usage

1. Build and open the app.
2. Click the ProxySwitcher menu bar icon.
3. Choose `Configure...` / `配置...` and set the proxy host and ports.
4. Use `Enable System Proxy` / `启用系统代理` or `Disable System Proxy` / `关闭系统代理`.
5. Use the `Terminal` menu to copy shell commands for a Terminal session.

ProxySwitcher uses the current primary network service, such as the active Wi-Fi or Ethernet service, for the main status and enable/disable actions. The `Network Services` / `网络服务` submenu still shows proxy settings for all enabled services, with the primary service marked by `*`. If the primary service cannot be detected, enable/disable falls back to all enabled network services.

Language can be changed from the `Language` / `语言` menu. The default is `Follow System` / `跟随系统`.

## Development

```sh
swift test
swift run ProxySwitcher
```

Build a local `.app` bundle:

```sh
sh scripts/build-app.sh
open .build/release/ProxySwitcher.app
```

## Notes

ProxySwitcher uses macOS `networksetup` under the hood. Some machines or managed environments may reject system proxy changes depending on local permissions and policy.

This project is primarily built for personal use, but it is open source. Issues and improvements are welcome, especially around macOS version compatibility and different network setups.

## Troubleshooting

- If the menu shows an authorization error, try launching the built `.app` normally instead of running commands from a restricted shell.
- If proxy state looks unexpected, check the `Network Services` / `网络服务` submenu to see which service is being read.
- Terminal proxy commands only affect the shell where you paste them. ProxySwitcher does not edit `.zshrc`, `.bashrc`, or other shell startup files.
