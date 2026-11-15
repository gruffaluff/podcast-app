import Foundation

// Per-show ad skipping (Paul, 15 Nov 2026): each show can follow the global
// "Skip ads automatically" setting (Default), or always / never skip ads by
// itself. Kept without model changes (CloudKit Production can't take new
// fields): one dictionary in UserDefaults, [feed link: "always" | "never"],
// synced with the other settings ("showAdSkip" in SettingsSync.keys). Shows
// on Default aren't stored.
enum ShowAdSkip {
    enum Mode: String, Hashable, CaseIterable {
        case followSettings = "default"
        case always
        case never
    }

    static let key = "showAdSkip"

    static let options: [(label: String, value: Mode)] = [
        (label: "Default", value: .followSettings),
        (label: "Always", value: .always),
        (label: "Never", value: .never),
    ]

    private static var stored: [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    static func mode(for feed: String?) -> Mode {
        guard let feed, !feed.isEmpty, let raw = stored[feed] else { return .followSettings }
        return Mode(rawValue: raw) ?? .followSettings
    }

    static func set(_ mode: Mode, for feed: String) {
        guard !feed.isEmpty else { return }
        var all: [String: String] = stored
        if mode == .followSettings {
            all[feed] = nil
        } else {
            all[feed] = mode.rawValue
        }
        if all.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(all, forKey: key)
        }
    }

    /// Whether ads in this show's episodes are skipped by themselves.
    static func skips(feed: String?, global: Bool) -> Bool {
        switch mode(for: feed) {
        case .followSettings: return global
        case .always: return true
        case .never: return false
        }
    }
}
