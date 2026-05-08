# zarge

**zarge** overrides the MagSafe LED: when your battery reaches a **preconfigured threshold** (default 90%), it turns the LED **green** while MagSafe is plugged in. Below that level, or when you unplug, it stops overriding and the system controls the LED again. It does not change charging or any other SMC behavior—only that LED.

## How it works

- **Runs in the background** on Apple Silicon MacBooks (with MagSafe) as an optional `launchd` service.
- **Watches** battery level and AC power using macOS power-source notifications (no fixed polling interval).
- **While plugged in** and battery is **at or above** your threshold, it **writes** the MagSafe LED to green via SMC.
- **Below the threshold**, or **when unplugged**, it **releases** LED control so macOS behaves normally.
- **Only that LED** is written: no charging limits, adapter tweaks, or other SMC keys.

This is a derivative work of [`batt`](https://github.com/charlie0129/batt) (GPL-2.0); the SMC wrapper code under `internal/smc/` is adapted from `batt`'s `pkg/smc/`.

## Why

`batt` and similar tools manage charging limits and use the LED as a side-effect. If you only want a visual cue at a chosen battery level — without giving up automatic charging — `zarge` is the smallest thing that does that.

## Build

Requires Apple Silicon and Go 1.24+.

```sh
go build ./cmd/zarge
```

## Quick check

```sh
sudo ./zarge status
```

Reads battery, plug state, and current LED. Writes nothing.

## Run as a launchd daemon

```sh
sudo ./zarge install      # copies binary to /usr/local/bin/zarge and bootstraps local.zarge
sudo launchctl print system/local.zarge
tail -f /tmp/zarge.log
sudo ./zarge uninstall    # stops, removes plist, removes binary
sudo ./zarge purge        # same as uninstall, also deletes /tmp/zarge.log
```

Use **`purge`** when you want no leftover log file; **`uninstall`** leaves `/tmp/zarge.log` on disk.

## Configuration

Flags on `zarge run`:

- `--threshold` — battery percent at which (and above) the LED is forced green (default `90`)

With the defaults, the LED turns green at `>=90%` while plugged in and returns to system control below `90%` or when MagSafe is unplugged.

To change the daemon's flags, edit `/Library/LaunchDaemons/local.zarge.plist` after install and `launchctl kickstart -k system/local.zarge`.

`zarge run` is event-driven: it wakes when macOS reports a power-source change, such as plug/unplug, charging-state changes, or battery percentage changes. It does not poll on a timer.

## License

GPL-2.0 (see [`LICENSE`](./LICENSE)). Inherited from `batt` because the SMC wrapper is adapted from it.
