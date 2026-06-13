import Foundation
import Dispatch

/// Watches one or more config files and fires a debounced callback when any of
/// them change. Editors commonly save atomically (write a temp file, then
/// rename over the target), which makes the original file descriptor stale, so
/// this re-arms a fresh watch on delete/rename to survive that pattern.
///
/// Concurrency: all mutable state (`sources`, `started`, `pendingWork`) is only
/// ever touched on the private serial `queue`. The class is marked
/// `@unchecked Sendable` because that serialization is enforced by convention,
/// not by the type system; every method that reads or writes state hops onto
/// `queue` first. The user-supplied `onChange` is `@Sendable`.
public final class ConfigWatcher: @unchecked Sendable {
    private struct Watch {
        let source: DispatchSourceFileSystemObject
        let fd: Int32
    }

    private let paths: [URL]
    private let debounce: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "ConfigWatcher.queue")

    // Mutable state — only mutate on `queue`.
    private var sources: [String: Watch] = [:]
    private var pendingWork: DispatchWorkItem?
    private var started = false

    private let rearmDelay: TimeInterval = 0.1
    private let maxRearmAttempts = 10

    public init(
        paths: [URL],
        debounce: TimeInterval = 0.2,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.paths = paths
        self.debounce = debounce
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// Begin watching. Idempotent: a second call while running is a no-op.
    /// Paths that don't currently exist are skipped (best-effort).
    public func start() {
        queue.async { [self] in
            guard !started else { return }
            started = true
            for url in paths {
                arm(path: url.path)
            }
        }
    }

    /// Cancel all sources, close all descriptors, and drop any pending callback.
    public func stop() {
        queue.sync { [self] in
            guard started else { return }
            started = false
            pendingWork?.cancel()
            pendingWork = nil
            for (_, watch) in sources {
                watch.source.cancel()
            }
            sources.removeAll()
        }
    }

    // MARK: - Private (all called on `queue`)

    /// Open `path` with O_EVTONLY and arm a filesystem-object source. No-op if
    /// the file can't be opened (e.g. it doesn't exist yet).
    private func arm(path: String) {
        // Drop any existing watch for this path first.
        if let existing = sources.removeValue(forKey: path) {
            existing.source.cancel()
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            self.handleEvent(path: path, flags: flags)
        }

        // Close the fd exactly once, when the source is fully cancelled.
        source.setCancelHandler {
            close(fd)
        }

        sources[path] = Watch(source: source, fd: fd)
        source.resume()
    }

    /// Handle a filesystem event: always debounce the callback; if the file was
    /// deleted or renamed out from under us, tear down and re-arm.
    private func handleEvent(path: String, flags: DispatchSource.FileSystemEvent) {
        guard started else { return }

        scheduleCallback()

        if flags.contains(.delete) || flags.contains(.rename) {
            // The current fd points at a now-detached inode; cancel it and try
            // to re-arm against whatever file now lives at this path.
            if let watch = sources.removeValue(forKey: path) {
                watch.source.cancel()
            }
            scheduleRearm(path: path, attempt: 0)
        }
    }

    /// Cancel a pending callback and schedule a fresh one `debounce` out.
    private func scheduleCallback() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [onChange] in
            onChange()
        }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    /// Retry arming a replaced file. Atomic saves can leave a brief window where
    /// no file exists at the path, so retry a few times before giving up.
    private func scheduleRearm(path: String, attempt: Int) {
        queue.asyncAfter(deadline: .now() + rearmDelay) { [self] in
            guard started else { return }
            guard sources[path] == nil else { return } // already re-armed

            if FileManager.default.fileExists(atPath: path) {
                arm(path: path)
            } else if attempt + 1 < maxRearmAttempts {
                scheduleRearm(path: path, attempt: attempt + 1)
            }
        }
    }
}
