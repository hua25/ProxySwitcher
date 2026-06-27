# ProxySwitcher

ProxySwitcher is a lightweight macOS menu bar app for checking and switching system proxy settings and copying Terminal proxy commands.

## Features

- Menu bar resident AppKit app.
- Stores one local proxy configuration.
- Supports HTTP, HTTPS, and SOCKS system proxy settings.
- Applies system proxy changes to all enabled macOS network services.
- Copies Terminal `export` and `unset` commands without editing shell startup files.

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
