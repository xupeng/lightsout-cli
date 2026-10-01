import AppKit
import CoreGraphics
import Darwin

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct Display: Codable {
    let id: UInt32
    let uuid: String
    let name: String
}

let stateURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/lightsout-cli/displays.json")

func displayIDs(active: Bool) throws -> [UInt32] {
    var count: UInt32 = 0
    let first = active ? CGGetActiveDisplayList(0, nil, &count) : CGGetOnlineDisplayList(0, nil, &count)
    guard first == .success else { throw CLIError("Cannot enumerate displays: \(first.rawValue)") }
    var ids = [UInt32](repeating: 0, count: Int(count))
    let result = active ? CGGetActiveDisplayList(count, &ids, &count) : CGGetOnlineDisplayList(count, &ids, &count)
    guard result == .success else { throw CLIError("Cannot enumerate displays: \(result.rawValue)") }
    return Array(ids.prefix(Int(count)))
}

func uuid(_ id: UInt32) -> String? {
    guard let value = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
    return CFUUIDCreateString(nil, value) as String
}

func displays() throws -> [Display] {
    var known: [Display] = []
    if FileManager.default.fileExists(atPath: stateURL.path) {
        known = try JSONDecoder().decode([Display].self, from: Data(contentsOf: stateURL))
    }
    for id in try displayIDs(active: false) {
        guard let identifier = uuid(id) else { continue }
        let name = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == id
        }?.localizedName ?? "Display \(id)"
        known.removeAll { $0.uuid == identifier }
        known.append(Display(id: id, uuid: identifier, name: name))
    }
    return known.sorted { $0.id < $1.id }
}

func resolve(_ display: Display) throws -> UInt32 {
    guard let identifier = CFUUIDCreateFromString(nil, display.uuid as CFString) else {
        throw CLIError("Invalid saved display UUID")
    }
    let id = CGDisplayGetDisplayIDFromUUID(identifier)
    guard id != kCGNullDirectDisplay, uuid(id) == display.uuid else {
        throw CLIError("Display is unavailable; reconnect its cable and run list")
    }
    return id
}

func configure(_ id: UInt32, enabled: Bool) throws {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
        throw CLIError("Cannot load SkyLight")
    }
    defer { dlclose(handle) }
    guard let symbol = dlsym(handle, "CGSConfigureDisplayEnabled") else {
        throw CLIError("This macOS version does not expose CGSConfigureDisplayEnabled")
    }
    typealias Configure = @convention(c) (CGDisplayConfigRef, UInt32, Bool) -> Int32
    let setEnabled = unsafeBitCast(symbol, to: Configure.self)
    var reference: CGDisplayConfigRef?
    let begin = CGBeginDisplayConfiguration(&reference)
    guard begin == .success, let config = reference else {
        throw CLIError("Cannot begin display configuration: \(begin.rawValue)")
    }
    let result = setEnabled(config, id, enabled)
    guard result == 0 else {
        CGCancelDisplayConfiguration(config)
        throw CLIError("Cannot configure display: \(result)")
    }
    let complete = CGCompleteDisplayConfiguration(config, .forSession)
    guard complete == .success else {
        throw CLIError("Cannot apply display configuration: \(complete.rawValue)")
    }
}

func run() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.isEmpty || args == ["--help"] || args == ["help"] {
        print("Usage: lightsout list | off <display-id> | on <display-id>\nChanges last for the current login session. Use list to find display IDs.")
        return
    }
    guard args == ["list"] || (args.count == 2 && ["off", "on"].contains(args[0]) && UInt32(args[1]) != nil) else {
        throw CLIError("Usage: lightsout list | off <display-id> | on <display-id>")
    }
    let known = try displays()
    let active = try displayIDs(active: true)
    if args == ["list"] {
        print("ID\tSTATE\tSIZE\tNAME")
        for display in known {
            let id = try? resolve(display)
            let isActive = id.map { active.contains($0) } ?? false
            let size = isActive ? "\(CGDisplayPixelsWide(id!))x\(CGDisplayPixelsHigh(id!))" : "-"
            print("\(display.id)\t\(isActive ? "on" : "off/unavailable")\t\(size)\t\(display.name)\(id == CGMainDisplayID() ? " (main)" : "")")
        }
        return
    }
    let requested = UInt32(args[1])!
    guard let display = known.first(where: { $0.id == requested }) else {
        throw CLIError("Unknown display ID; run list first")
    }
    let id = try resolve(display)
    let enabled = args[0] == "on"
    if !enabled && active.contains(id) && active.count <= 1 {
        throw CLIError("Refusing to disable the last active display")
    }
    try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(known).write(to: stateURL, options: .atomic)
    try configure(id, enabled: enabled)
    print("Display \(requested): requested \(enabled ? "on" : "off")")
}

do { try run() } catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
