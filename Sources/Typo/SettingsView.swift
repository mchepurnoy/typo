import AppKit
import Carbon
import Engine
import SwiftUI
import UniformTypeIdentifiers

/// The settings window. Every control writes straight to `SettingsStore` (or the login item), which
/// hands the change to the Engine at once: nothing needs a restart.
struct SettingsView: View {
    let settings: SettingsStore
    let launchAtLogin: LaunchAtLogin
    let status: Status

    var body: some View {
        TabView {
            GeneralTab(settings: settings, launchAtLogin: launchAtLogin)
                .tabItem { Label("General", systemImage: "gearshape") }
            WordsTab(settings: settings)
                .tabItem { Label("Words", systemImage: "text.badge.checkmark") }
            ExcludedAppsTab(settings: settings)
                .tabItem { Label("Excluded Apps", systemImage: "nosign") }
            LayoutsTab(missingLanguages: status.missingLanguages)
                .tabItem { Label("Layouts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 400)
    }
}

private struct GeneralTab: View {
    @Bindable var settings: SettingsStore
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
            if launchAtLogin.needsApproval {
                Text("Allow Typo in System Settings → General → Login Items.").foregroundStyle(.secondary)
            }

            Picker("Convert the last word", selection: $settings.hotkey) {
                ForEach(SettingsStore.Hotkey.allCases, id: \.self) { hotkey in
                    Text("Double-tap \(hotkey.displayName)").tag(hotkey)
                }
            }

            Toggle("Switch the keyboard layout automatically", isOn: $settings.switchesLayout)
            if settings.switchesLayout {
                Stepper(
                    "After \(settings.switchAfter) correction\(settings.switchAfter == 1 ? "" : "s") in a row",
                    value: $settings.switchAfter, in: 1...5)
                Text("macOS's \"Automatically switch to a document's input source\" can undo the switch; turn it off in Keyboard settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Toggle("Fix typos in the right layout (teh → the)", isOn: $settings.fixesTypos)
            Toggle("Play a sound on each correction", isOn: $settings.playsSound)
        }
        .formStyle(.grouped)
    }
}

private struct WordsTab: View {
    let settings: SettingsStore
    @State private var newException = ""
    @State private var layouts: [SystemLayout] = []

    var body: some View {
        Form {
            Section {
                ForEach(settings.exceptions.sorted(), id: \.self) { word in
                    WordRow(word: word, conversion: conversion(of: word), isKept: true) { settings.removeException(word) }
                }
                HStack {
                    TextField("Add a word", text: $newException)
                        .onSubmit(add)
                    Button("Add", action: add).disabled(newException.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Exceptions")
            } footer: {
                Text("Kept as typed, never converted. Backspace right after a correction adds the word here.")
            }

            Section {
                if settings.learnedWords.isEmpty {
                    Text("None yet").foregroundStyle(.secondary)
                }
                ForEach(settings.learnedWords.sorted(), id: \.self) { word in
                    WordRow(word: word, conversion: conversion(of: word), isKept: false) { settings.forgetLearnedWord(word) }
                }
            } header: {
                Text("Learned words")
            } footer: {
                Text("Always converted. Converting a word with the hotkey adds it here.")
            }
        }
        .formStyle(.grouped)
        .onAppear { layouts = SystemLayouts.enabled() }
    }

    private func conversion(of word: String) -> String? {
        SystemLayouts.conversion(of: word, among: layouts)
    }

    private func add() {
        settings.addException(newException)
        newException = ""
    }
}

private struct WordRow: View {
    let word: String
    /// What the word reads as in the other script: "cegth → супер" for a learned word, struck
    /// through for an exception (it stays as typed).
    let conversion: String?
    let isKept: Bool
    let remove: () -> Void

    var body: some View {
        HStack {
            Text(word)
            if let conversion, isKept {
                Text(conversion).strikethrough().foregroundStyle(.tertiary).help("Not converted to \(conversion)")
            } else if let conversion {
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                Text(conversion).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Remove")
        }
    }
}

private struct ExcludedAppsTab: View {
    let settings: SettingsStore

    var body: some View {
        Form {
            Section {
                if settings.excludedApps.isEmpty {
                    Text("Typo works in every app.").foregroundStyle(.secondary)
                }
                ForEach(settings.excludedApps.sorted(), id: \.self) { bundleID in
                    HStack {
                        AppLabel(bundleID: bundleID)
                        Spacer()
                        Button { settings.include(appWithBundleID: bundleID) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help("Remove")
                    }
                }
                Button("Add App…", action: chooseApp)
            } footer: {
                Text("Typo ignores these apps entirely.")
            }
        }
        .formStyle(.grouped)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier { settings.exclude(appWithBundleID: bundleID) }
        }
    }
}

private struct AppLabel: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
                Text(url.deletingPathExtension().lastPathComponent)
            } else {
                Text(bundleID)
            }
        }
    }
}

private struct LayoutsTab: View {
    let missingLanguages: [String]
    @State private var layouts: [SystemLayout] = []

    /// Languages typo can judge right now: supported, with their data loaded.
    private func usable(_ language: Language?) -> Language? {
        language.flatMap { missingLanguages.contains($0.rawValue) ? nil : $0 }
    }

    var body: some View {
        let scripts = Set(layouts.compactMap { usable($0.language)?.script })
        Form {
            Section {
                ForEach(layouts, id: \.id) { layout in
                    HStack {
                        Text(layout.name)
                        Spacer()
                        if let language = usable(layout.language) {
                            Label(language.displayName, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if layout.language != nil {
                            Text("Language data missing").foregroundStyle(.orange)
                        } else {
                            Text("Not supported").foregroundStyle(.secondary)
                        }
                    }
                }
                if scripts.count < 2 {
                    Label("Nothing to correct: enable a supported layout of another script, e.g. Russian – PC next to U.S.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Typo corrects between supported layouts of different scripts (Latin ↔ Cyrillic). Supported languages: \(Language.allCases.map(\.displayName).formatted(.list(type: .and))).")
            }
        }
        .formStyle(.grouped)
        .onAppear { layouts = SystemLayouts.enabled() }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))) { _ in
            layouts = SystemLayouts.enabled()
        }
    }
}

extension SettingsStore.Hotkey {
    var displayName: String {
        switch self {
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .command: "Command"
        }
    }
}

extension Language {
    var displayName: String {
        switch self {
        case .english: "English"
        case .russian: "Russian"
        case .german: "German"
        case .spanish: "Spanish"
        }
    }
}
