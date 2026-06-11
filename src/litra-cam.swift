// Build: swiftc litra-cam.swift -framework CoreMediaIO -o litra-cam

import Foundation
import CoreMediaIO

// ── Config ─────────────────────────────────────────────────────────
// Adjust to match `which litra`
let litraPath = "/opt/homebrew/bin/litra"

// ── USB detection ──────────────────────────────────────────────────
func litraConnected() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
    task.arguments = ["-p", "IOUSB", "-w0"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    guard (try? task.run()) != nil else { return false }
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    task.waitUntilExit()
    return output.lowercased().contains("litra")
}

// ── CoreMediaIO helpers ────────────────────────────────────────────
func globalAddress(_ selector: CMIOObjectPropertySelector) -> CMIOObjectPropertyAddress {
    CMIOObjectPropertyAddress(
        mSelector: selector,
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
}

func allCameraDevices() -> [CMIOObjectID] {
    var addr = globalAddress(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
    var size: UInt32 = 0
    CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size)
    let count = Int(size) / MemoryLayout<CMIOObjectID>.size
    guard count > 0 else { return [] }
    var devices = [CMIOObjectID](repeating: 0, count: count)
    var used: UInt32 = 0
    CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &devices)
    // Only keep devices that have the IsRunningSomewhere property (video cameras, not audio)
    return devices.filter { id in
        var a = globalAddress(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
        return CMIOObjectHasProperty(id, &a)
    }
}

func isInUse(_ deviceID: CMIOObjectID) -> Bool {
    var addr = globalAddress(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
    var value: UInt32 = 0
    var used: UInt32 = 0
    CMIOObjectGetPropertyData(deviceID, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &value)
    return value != 0
}

// ── State machine ──────────────────────────────────────────────────
// Per-device tracking so multiple cameras coalesce correctly
var cameraStates: [CMIOObjectID: Bool] = [:]

func runLitra(_ command: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: litraPath)
    task.arguments = [command]
    do { try task.run() }
    catch { fputs("litra \(command) failed: \(error)\n", stderr) }
}

func handleChange(for deviceID: CMIOObjectID) {
    let wasAnyActive = cameraStates.values.contains(true)
    cameraStates[deviceID] = isInUse(deviceID)
    let isAnyActive = cameraStates.values.contains(true)

    // Suppress redundant events (e.g. Zoom + Chrome both open the camera)
    guard isAnyActive != wasAnyActive else { return }

    let cmd = isAnyActive ? "on" : "off"

    guard litraConnected() else {
        print("[\(Date())] Camera \(cmd) — Litra not connected, skipping")
        return
    }

    print("[\(Date())] Camera \(cmd) — running: litra \(cmd)")
    runLitra(cmd)
}

// ── Entry point ────────────────────────────────────────────────────
let cameras = allCameraDevices()
guard !cameras.isEmpty else {
    fputs("No camera devices found\n", stderr)
    exit(1)
}

print("Watching \(cameras.count) camera device(s)")

for id in cameras {
    cameraStates[id] = isInUse(id)  // seed initial state
}

for id in cameras {
    var addr = globalAddress(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
    CMIOObjectAddPropertyListenerBlock(id, &addr, .main) { _, _ in
        handleChange(for: id)
    }
}

RunLoop.main.run()
