# litra-cam

A lightweight macOS daemon that automatically toggles a Logitech Litra light when your camera turns on or off. Uses CoreMediaIO to observe camera state directly — the same signal that drives the hardware green LED — so it's event-driven with no polling.

The light is only toggled if it's actually connected via USB, so it's safe to leave running whether or not you're at your desk/dock.

## How it works

- Watches `kCMIODevicePropertyDeviceIsRunningSomewhere` on all connected camera devices, and re-scans whenever cameras appear or disappear (e.g. dock/undock) — no restart needed
- Checks USB for a connected Litra before acting on any camera event
- Coalesces multiple camera consumers (e.g. Zoom + Chrome open simultaneously) so `litra on/off` is only called once per real state transition
- Runs as a LaunchAgent, starts on login, restarts automatically if it crashes

## Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools: `xcode-select --install`
- The [`litra`](https://github.com/timrogers/litra-rs) CLI (`brew install litra`). It is looked up at `/opt/homebrew/bin/litra`, then `/usr/local/bin/litra`.

## Install

### Homebrew

```bash
brew install jslow421/tap/litra-cam
brew services start litra-cam
```

### From GitHub

```bash
git clone https://github.com/jslow421/camera-light-automation.git
cd camera-light-automation
make install
```

`make install` builds the binary, copies it to `/usr/local/bin` (override with `PREFIX=...`), writes `~/Library/LaunchAgents/dev.jslowik.litra-cam.plist`, and loads it with `launchctl bootstrap`. It starts on login and restarts automatically if it exits.

## Redeploy

After pulling changes or editing the source:

```bash
make redeploy
```

Or, for the Homebrew install: `brew upgrade litra-cam && brew services restart litra-cam`.

To bounce the daemon without rebuilding:

```bash
launchctl kickstart -k gui/$(id -u)/dev.jslowik.litra-cam
```

## Verify

```bash
launchctl print gui/$(id -u)/dev.jslowik.litra-cam | grep -E 'state|pid'
tail -f ~/Library/Logs/litra-cam.log
```

Toggle your camera; you should see lines like:

```
[2026-01-15 09:32:11 +0000] Watching 1 camera device(s)
[2026-01-15 09:32:20 +0000] Camera on — running: litra on
[2026-01-15 09:45:02 +0000] Camera off — running: litra off
```

(Homebrew services logs go to Homebrew's log directory, `$(brew --prefix)/var/log/litra-cam.log`.)

## Troubleshooting

**Daemon not running** — check `~/Library/Logs/litra-cam.log`, or run `litra-cam` manually in a terminal. TCC may prompt for camera access on first run; approve it.

**Light doesn't toggle but log shows camera events** — the Litra USB check is failing. Confirm `ioreg -p IOUSB -w0 | grep -i litra` returns output when the light is connected, and that `litra` is installed in one of the paths above.

**Migrating from an older install** (labels `com.john.litra-cam` / `com.jslowik.litra-cam`):

```bash
launchctl bootout gui/$(id -u)/com.john.litra-cam 2>/dev/null
rm -f ~/Library/LaunchAgents/com.john.litra-cam.plist ~/Library/LaunchAgents/com.jslowik.litra-cam.plist
make install
```

## Uninstall

```bash
make uninstall            # GitHub install
brew services stop litra-cam && brew uninstall litra-cam   # Homebrew install
```
