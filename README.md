# Zarge

Zarge turns the MagSafe LED green when your battery reaches a threshold you pick (default 90%), while MagSafe is plugged in. Below the threshold, or unplugged, macOS controls the LED as usual. It doesn't touch charging or any other SMC setting, only that LED.

Zarge is a small settings window plus a background helper. Open Zarge, install the helper, set the threshold, close the window. The helper keeps working with no app or menu bar icon running.

## Layout

- `Sources/ZargeCore`: SMC access (`ACLC`, `AC-W`, `BUIC`), the LED decisions, power-source events, settings, and the XPC protocol. Shared by both executables.
- `Sources/ZargeHelper`: `zarge-helper`, the root launchd daemon. It watches power events, writes the LED, and stores the threshold in `/Library/Application Support/Zarge/settings.json`. On SIGTERM (uninstall) it hands the LED back to macOS.
- `Sources/Zarge`: the Liquid Glass settings panel. It registers the helper with `SMAppService` and sets the threshold over XPC. Closing it quits the app.
- `Sources/CSMC`: the AppleSMC struct, declared in C so Swift gets its exact 80-byte layout.
- `Resources`: `Info.plist`, the helper's launchd plist, and `Zarge.icon` (Icon Composer).

The app and helper only accept XPC peers signed by the same team, checked with `setCodeSigningRequirement`.

## Build

Requires an Apple Silicon MacBook with MagSafe, macOS 26 or later, and Xcode 26 or later.

```sh
swift test                 # unit tests
scripts/build-app.sh       # build/Zarge.app, signed with your first Apple Development or Developer ID identity
open build/Zarge.app
```

Then click **Install Helper** and allow it in System Settings → General → Login Items & Extensions.

The helper runs from inside the bundle it was installed from. After rebuilding, restart it so it picks up the new binary:

```sh
sudo launchctl kickstart -k system/dev.zarge.Zarge.helper
```

If you move the bundle, uninstall the helper first and install it again from the new location.

## Debugging

```sh
build/Zarge.app/Contents/MacOS/zarge-helper status    # battery, AC, LED and charging state; writes nothing
launchctl print system/dev.zarge.Zarge.helper           # whether the helper is running, its pid and restarts
/usr/bin/log stream --predicate 'subsystem == "dev.zarge.Zarge.helper"'
```

Use `/usr/bin/log`: in zsh, a bare `log` is a different, built-in command.

## Shipping outside the App Store

The Mac App Store can't take Zarge: the sandbox blocks SMC writes and root helpers. Distribute it directly instead:

1. Sign with a Developer ID Application certificate: `ZARGE_SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh` (adds the secure timestamp).
2. Zip and notarize: `ditto -c -k --keepParent build/Zarge.app Zarge.zip && xcrun notarytool submit Zarge.zip --keychain-profile <profile> --wait`.
3. Staple: `xcrun stapler staple build/Zarge.app`.

The bundle identifiers (`dev.zarge.Zarge` and `.helper`) are placeholders. Change them in `Sources/ZargeCore/HelperProtocol.swift`, `Resources/`, and `scripts/build-app.sh` together.

## Acknowledgments

The SMC keys and MagSafe LED values were first worked out in [`batt`](https://github.com/charlie0129/batt), which an earlier Go version of Zarge was based on.

## License

See [LICENSE](LICENSE).
