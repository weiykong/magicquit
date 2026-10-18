import AppKit
import Combine

/// Single source of truth for user settings, persisted to UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let idleMinutes = "idleMinutes"
        static let showQuitButton = "showCloseButton" // key kept from 1.x
        static let quitOnLastWindowClosed = "quitOnLastWindowClosed"
        static let confirmBeforeAutoQuit = "confirmBeforeAutoQuit"
        static let excludedApps = "excludedApps" // unified (was excludedApps + excludedApps)
        static let legacyHours = "hoursUntilClose"
        static let legacyToggles = "com.MagicQuit.toggleStatus"
    }

    static let defaultWindowQuitExcluded: Set<String> = [
        "com.apple.Music",
        "com.spotify.client",
        "com.apple.podcasts",
        "org.videolan.vlc",
    ]

    private let defaults: UserDefaults

    @Published var idleMinutes: Int {
        didSet { defaults.set(idleMinutes, forKey: Keys.idleMinutes) }
    }

    @Published var showQuitButton: Bool {
        didSet { defaults.set(showQuitButton, forKey: Keys.showQuitButton) }
    }

    @Published var quitOnLastWindowClosed: Bool {
        didSet { defaults.set(quitOnLastWindowClosed, forKey: Keys.quitOnLastWindowClosed) }
    }

    /// When enabled, automatic quits show a 20-second countdown banner with Cancel.
    @Published var confirmBeforeAutoQuit: Bool {
        didSet { defaults.set(confirmBeforeAutoQuit, forKey: Keys.confirmBeforeAutoQuit) }
    }

    /// Bundle identifiers for apps never quit by either mechanism (unified from idle/window exclusions).
    @Published var excludedApps: Set<String> {
        didSet { defaults.set(Array(excludedApps).sorted(), forKey: Keys.excludedApps) }
    }

    /// Default exclusions for window-close quitting (media players); menu checkbox also protects them.
    static let defaultExcludedApps: Set<String> = [
        "com.apple.Music", "com.spotify.client", "com.apple.podcasts", "org.videolan.vlc"
    ]

    /// 1.x stored per-app enablement keyed by localized app name; consumed lazily as apps appear.
    private var legacyTogglesByName: [String: Bool]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let minutes = defaults.object(forKey: Keys.idleMinutes) as? Int {
            idleMinutes = minutes
        } else if let hours = defaults.object(forKey: Keys.legacyHours) as? Int {
            idleMinutes = IdleDuration.stepAtLeast(minutes: hours * 60)
        } else {
            idleMinutes = IdleDuration.defaultMinutes
        }

        showQuitButton = defaults.bool(forKey: Keys.showQuitButton)
        quitOnLastWindowClosed = defaults.bool(forKey: Keys.quitOnLastWindowClosed)
        confirmBeforeAutoQuit = defaults.object(forKey: Keys.confirmBeforeAutoQuit) as? Bool ?? true
        excludedApps = Set(defaults.stringArray(forKey: Keys.excludedApps) ?? [])
        if excludedApps.isEmpty {
            excludedApps = AppSettings.defaultExcludedApps
        }

        if let data = defaults.data(forKey: Keys.legacyToggles),
           let toggles = try? JSONDecoder().decode([String: Bool].self, from: data) {
            legacyTogglesByName = toggles
        } else {
            legacyTogglesByName = [:]
        }
    }

    /// Consume the 1.x per-app toggle for an app once its bundle identifier is known.
    func migrateLegacyToggleIfNeeded(appName: String?, bundleId: String?) {
        guard let appName, let bundleId,
              let enabled = legacyTogglesByName.removeValue(forKey: appName) else { return }
        if !enabled {
            excludedApps.insert(bundleId)
        }
        persistLegacyToggles()
    }

    private func persistLegacyToggles() {
        if legacyTogglesByName.isEmpty {
            defaults.removeObject(forKey: Keys.legacyToggles)
        } else if let data = try? JSONEncoder().encode(legacyTogglesByName) {
            defaults.set(data, forKey: Keys.legacyToggles)
        }
    }
}
