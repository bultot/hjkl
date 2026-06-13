import Testing
import Foundation
@testable import CheatCore

/// FS-event tests are inherently timing-dependent. Timeouts are generous (2s)
/// and the suite is serialized to avoid temp-file contention. If these prove
/// flaky on a given CI runner, they can be skipped without affecting the
/// correctness of ConfigWatcher itself.
@Suite("ConfigWatcher", .serialized)
struct ConfigWatcherTests {
    /// Await `predicate` becoming true, polling until `timeout` elapses.
    private func waitFor(
        timeout: TimeInterval,
        _ predicate: @Sendable () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        return predicate()
    }

    @Test("fires onChange when a watched file is written")
    func firesOnWrite() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigWatcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("config.txt")
        try "initial".write(to: file, atomically: true, encoding: .utf8)

        let fired = Fired()
        let watcher = ConfigWatcher(paths: [file], debounce: 0.05) {
            fired.set()
        }
        watcher.start()
        defer { watcher.stop() }

        // Give the source a beat to arm before mutating.
        try await Task.sleep(nanoseconds: 200_000_000)

        let handle = try FileHandle(forWritingTo: file)
        handle.seekToEndOfFile()
        handle.write(Data(" changed".utf8))
        try handle.close()

        let ok = await waitFor(timeout: 2.0) { fired.value }
        #expect(ok, "onChange should fire after a direct write")
    }

    @Test("survives atomic save (file replaced)")
    func survivesAtomicReplace() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigWatcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("config.txt")
        try "initial".write(to: file, atomically: true, encoding: .utf8)

        let fired = Fired()
        let watcher = ConfigWatcher(paths: [file], debounce: 0.05) {
            fired.set()
        }
        watcher.start()
        defer { watcher.stop() }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Atomic save: write to a temp file then rename over the target.
        try "first".write(to: file, atomically: true, encoding: .utf8)
        let firstOK = await waitFor(timeout: 2.0) { fired.value }
        #expect(firstOK, "onChange should fire after the first atomic replace")

        // Reset and ensure the re-armed watch still detects a second replace.
        fired.reset()
        try await Task.sleep(nanoseconds: 300_000_000) // let re-arm settle
        try "second".write(to: file, atomically: true, encoding: .utf8)
        let secondOK = await waitFor(timeout: 2.0) { fired.value }
        #expect(secondOK, "onChange should still fire after a re-armed watch")
    }
}

/// Tiny thread-safe flag for the @Sendable callback to flip.
private final class Fired: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return flag
    }
    func set() {
        lock.lock(); flag = true; lock.unlock()
    }
    func reset() {
        lock.lock(); flag = false; lock.unlock()
    }
}
