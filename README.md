# litra-cam

A lightweight macOS daemon that automatically toggles a Logitech Litra light when your camera turns on or off. Uses CoreMediaIO to observe camera state directly — the same signal that drives the hardware green LED — so it's event-driven with no polling.

The light is only toggled if it's actually connected via USB, so it's safe to leave running whether or not you're at your desk/dock.

## How it works

- Watches `kCMIODevicePropertyDeviceIsRunningSomewhere` on all connected camera devices
- Checks USB for a connected Litra before acting on any camera event
- Coalesces multiple camera consumers (e.g. Zoom + Chrome open simultaneously) so `litra on/off` is only called once per real state transition
- Runs as a LaunchAgent, starts on login, restarts automatically if it crashes

## Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools: `xcode-select --install`
- The [`litra`](https://github.com/beaushinkle/litra-rs) CLI installed, e.g. via Homebrew

Confirm the path to `litra` before building:

```bash
which litra
```

If it's not `/opt/homebrew/bin/litra`, update the `litraPath` constant at the top of `litra-cam.swift` before compiling.

## Build

```bash
swiftc litra-cam.swift -framework CoreMediaIO -o litra-cam
```

## Install

Copy the compiled binary to `/usr/local/bin`:

```bash
sudo cp litra-cam /usr/local/bin/litra-cam
```

## Deploy

Register it as a LaunchAgent so it runs on every login:

```bash
cat > ~/Library/LaunchAgents/com.john.litra-cam.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.john.litra-cam</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/litra-cam</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/litra-cam.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/litra-cam.log</string>
</dict>
</plist>
EOF
```

Then load it for the current session (this only needs to be done once — subsequent logins are automatic):

```bash
launchctl load ~/Library/LaunchAgents/com.john.litra-cam.plist
```

## Verify

Check that the daemon is running (a non-zero PID means it's alive):

```bash
launchctl list | grep litra
```

Tail the log and toggle your camera to confirm end-to-end:

```bash
tail -f /tmp/litra-cam.log
```

You should see timestamped lines like:

```
Watching 1 camera device(s)
[2026-01-15 09:32:11 +0000] Camera on — running: litra on
[2026-01-15 09:45:02 +0000] Camera off — running: litra off
```

## Troubleshooting

**PID is 0 in `launchctl list`** — the daemon exited. Check `/tmp/litra-cam.log` for the reason. Common causes:

- Wrong path to `litra` — update `litraPath` in the source, recompile, and reinstall
- No camera devices found — run `/usr/local/bin/litra-cam` manually in a terminal to see the error directly
- TCC camera permission — macOS may prompt for camera access on first run; approve it

**Light doesn't toggle but log shows camera events** — the Litra USB check is failing. Confirm `ioreg -p IOUSB -w0 | grep -i litra` returns output when the light is connected.

**Rebuilding after source changes** — recompile, reinstall the binary, then bounce the daemon:

```bash
swiftc litra-cam.swift -framework CoreMediaIO -o litra-cam
sudo cp litra-cam /usr/local/bin/litra-cam
launchctl stop com.john.litra-cam   # KeepAlive will restart it automatically
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.john.litra-cam.plist
rm ~/Library/LaunchAgents/com.john.litra-cam.plist
sudo rm /usr/local/bin/litra-cam
```
