import Foundation

/// Holds the known providers and resolves which one to show for a given context.
public struct ProviderRegistry: Sendable {
    public let providers: [any ShortcutProvider]

    public init(_ providers: [any ShortcutProvider]) {
        self.providers = providers
    }

    /// The default set shipped with the app. The app seeds/overrides from Settings.
    public static var defaults: ProviderRegistry {
        ProviderRegistry(allKnownProviders())
    }

    /// Provider whose `matchBundleIDs` contains the frontmost app's bundle id.
    public func provider(forBundleID bundleID: String) -> (any ShortcutProvider)? {
        providers.first { $0.matchBundleIDs.contains(bundleID) }
    }

    /// Provider by stable id.
    public func provider(id: String) -> (any ShortcutProvider)? {
        providers.first { $0.id == id }
    }

    /// Providers to show as tabs: those with a config present, plus always-available ones.
    public var available: [any ShortcutProvider] {
        providers.filter { $0.isInstalled || $0.alwaysAvailable }
    }
}

/// The compile-time list of every provider hjkl knows how to parse.
/// Agents append their providers here as they land.
public func allKnownProviders() -> [any ShortcutProvider] {
    [
        CmuxProvider(),
        AeroSpaceProvider(),
        ClaudeCodeProvider(),
        GhosttyProvider(),
        GitProvider(),
        HeliumProvider(),
        LazygitProvider(),
        NeovimProvider(),
        SkhdProvider(),
        TmuxProvider(),
        ZshProvider(),
    ]
}
