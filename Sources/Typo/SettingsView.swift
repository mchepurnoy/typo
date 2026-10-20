import AppKit
import Carbon
import Engine
import SwiftUI
import UniformTypeIdentifiers

/// The settings window. Every control writes straight to `SettingsStore` (or the login item), which
/// hands the change to the Engine at once: nothing needs a restart.
struct SettingsView: View {
    let settings: SettingsStore
    let pauseHotkey: PauseHotkey
    let launchAtLogin: LaunchAtLogin
    let status: Status
    let statistics: StatisticsStore

    var body: some View {
        TabView {
            GeneralTab(settings: settings, pauseHotkey: pauseHotkey, launchAtLogin: launchAtLogin)
                .tabItem { Label("General", systemImage: "gearshape") }
            WordsTab(settings: settings)
                .tabItem { Label("Words", systemImage: "text.badge.checkmark") }
            ExcludedAppsTab(settings: settings)
                .tabItem { Label("Excluded Apps", systemImage: "nosign") }
            LayoutsTab(missingLanguages: status.missingLanguages)
                .tabItem { Label("Layouts", systemImage: "keyboard") }
            StatisticsTab(statistics: statistics)
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
        }
        .frame(width: 520, height: 400)
    }
}

private struct GeneralTab: View {
    @Bindable var settings: SettingsStore
    @Bindable var pauseHotkey: PauseHotkey
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

            LabeledContent("Pause or resume Typo") {
                ShortcutRecorder(shortcut: $settings.pauseShortcut, isRecording: $pauseHotkey.isSuspended)
            }
            if let refused = pauseHotkey.refused {
                Text("Another app uses \(refused.displayName), so it was removed; choose another shortcut.")
                    .font(.caption).foregroundStyle(.orange)
            }

            Toggle("Switch the keyboard layout automatically", isOn: $settings.switchesLayout)
            if settings.switchesLayout {
                Stepper("After \(settings.switchAfter) corrections in a row", value: $settings.switchAfter, in: 1...5)
                Text("macOS's \"Automatically switch to a document's input source\" can undo the switch; turn it off in Keyboard settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Toggle("Fix typos in the right layout (teh → the)", isOn: $settings.fixesTypos)
            Toggle("Add ё, umlauts and accents where certain (еще → ещё, konnen → können)", isOn: $settings.restoresAccents)
            Toggle("Play a sound on each correction", isOn: $settings.playsSound)
        }
        .formStyle(.grouped)
    }
}

/// Records a shortcut: click, then press a key combination, or press modifiers together and release
/// them. Escape cancels, Delete clears.
private struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @Binding var isRecording: Bool
    @State private var monitor: Any?
    /// Every modifier held since the last time none was, unless a key was pressed meanwhile.
    @State private var tapped: NSEvent.ModifierFlags = []

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if isRecording { stop() } else { start() }
            } label: {
                if isRecording {
                    Text("Press a shortcut…")
                } else if let shortcut {
                    Text(verbatim: shortcut.displayName)
                } else {
                    Text("Record Shortcut")
                }
            }
            .help("Two modifiers alone (⌃⌘), a key with ⌘, ⌥ or ⌃, or a function key. Esc cancels.")
            if shortcut != nil, !isRecording {
                Button { shortcut = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .help("Clear")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        tapped = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                let held = event.modifierFlags.intersection([.control, .option, .shift, .command])
                tapped.formUnion(held)
                if held.isEmpty {
                    if let recorded = Shortcut(modifiersAlone: tapped) {
                        shortcut = recorded
                        stop()
                    }
                    tapped = []
                }
                return event
            }
            tapped = []
            let plain = event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift])
            if plain, event.keyCode == kVK_Escape {
                stop()
            } else if plain, event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                shortcut = nil
                stop()
            } else if let recorded = Shortcut(event) {
                shortcut = recorded
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}

/// One list at a time, newest first, with a search. There can be thousands of words, so their order
/// and conversions are worked out when a list or the enabled layouts change, never on a redraw, and
/// only the newest are shown until asked.
private struct WordsTab: View {
    private enum WordList { case exceptions, learnedWords }

    /// Words shown before "Show all".
    private static let shownFirst = 50

    let settings: SettingsStore
    @State private var shown = WordList.exceptions
    @State private var search = ""
    @State private var showsAll = false
    @State private var conversion = WordConversion(layouts: [])
    /// Both lists newest first, each word with its conversion.
    @State private var exceptions: [ListedWord] = []
    @State private var learnedWords: [ListedWord] = []

    var body: some View {
        let words = matching(shown == .exceptions ? exceptions : learnedWords)
        VStack(alignment: .leading, spacing: 10) {
            Picker("Words", selection: $shown) {
                Text("Exceptions").tag(WordList.exceptions)
                Text("Learned words").tag(WordList.learnedWords)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)

            List {
                // A List is lazy: with "Show all", only the rows scrolled to are made
                ForEach(showsAll ? words[...] : words.prefix(Self.shownFirst)) { listed in
                    WordRow(word: listed.word, conversion: listed.conversion, isKept: shown == .exceptions) {
                        remove(listed.word)
                    }
                }
                if !showsAll, words.count > Self.shownFirst {
                    Button("Show all (\(words.count))") { showsAll = true }
                        .buttonStyle(.link)
                }
                if words.isEmpty, search.isEmpty {
                    Text("None yet").foregroundStyle(.secondary)
                } else if words.isEmpty {
                    Text("No matches").foregroundStyle(.secondary)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            if shown == .exceptions {
                AddWordField(settings: settings)
                Text("Kept as typed, never converted. Backspace right after a correction adds the word here.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Always converted. Converting a word with the hotkey adds it here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear(perform: readLayouts)
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))) { _ in
            readLayouts()
        }
        .onChange(of: settings.exceptions) { exceptions = listed(settings.exceptions, by: conversion) }
        .onChange(of: settings.learnedWords) { learnedWords = listed(settings.learnedWords, by: conversion) }
        .onChange(of: shown) { showsAll = false }
    }

    /// The words whose typed form or conversion contains the search, ignoring case.
    private func matching(_ words: [ListedWord]) -> [ListedWord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return query.isEmpty ? words : words.filter { $0.searchText.contains(query) }
    }

    private func readLayouts() {
        let conversion = WordConversion(layouts: SystemLayouts.enabled())
        self.conversion = conversion
        exceptions = listed(settings.exceptions, by: conversion)
        learnedWords = listed(settings.learnedWords, by: conversion)
    }

    /// The store keeps the oldest first; the tab shows the newest first.
    private func listed(_ words: [String], by conversion: WordConversion) -> [ListedWord] {
        words.reversed().map { ListedWord(word: $0, conversion: conversion($0)) }
    }

    private func remove(_ word: String) {
        if shown == .exceptions { settings.removeException(word) } else { settings.forgetLearnedWord(word) }
    }
}

private struct ListedWord: Identifiable {
    let word: String
    let conversion: String?
    /// The word and its conversion, lowercased, for the search.
    let searchText: String
    var id: String { word }

    init(word: String, conversion: String?) {
        self.word = word
        self.conversion = conversion
        searchText = (conversion.map { "\(word)\n\($0)" } ?? word).lowercased()
    }
}

/// A view of its own, so typing a word redraws the field and not the list.
private struct AddWordField: View {
    let settings: SettingsStore
    @State private var word = ""

    var body: some View {
        HStack {
            TextField("Add a word", text: $word)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            Button("Add", action: add).disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func add() {
        settings.addException(word)
        word = ""
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
    private static var supportedLanguages: String {
        Language.allCases.map(\.displayName).formatted(.list(type: .and))
    }

    let missingLanguages: [String]
    @State private var layouts: [SystemLayout] = []
    @State private var keyMaps: [String: [String: Key]] = [:]

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
                Text("Typo corrects between supported layouts of different scripts (Latin ↔ Cyrillic). Supported languages: \(Self.supportedLanguages).")
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

/// Words fixed and an estimate of the time saved, for today, 7 and 30 days. It reads the store's
/// counts, so it updates as rewrites happen while it is open.
private struct StatisticsTab: View {
    @Bindable var statistics: StatisticsStore
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section {
                if statistics.isKept {
                    let totals = [1, 7, 30].map(statistics.totals(days:))
                    Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            Text("Today")
                            Text("7 days")
                            Text("30 days")
                        }
                        .foregroundStyle(.secondary)
                        GridRow {
                            Text("Words fixed").gridColumnAlignment(.leading)
                            ForEach(totals.indices, id: \.self) { Text(totals[$0].wordsFixed, format: .number) }
                        }
                        GridRow {
                            Text("Time saved")
                            ForEach(totals.indices, id: \.self) { Self.timeSaved(totals[$0].secondsSaved) }
                        }
                    }
                    .monospacedDigit()
                } else {
                    Text("Statistics are off.").foregroundStyle(.secondary)
                }
            } footer: {
                Text("Time saved is an estimate: noticing a mistake, erasing the word and typing it again.")
            }

            Section {
                Toggle("Keep statistics", isOn: $statistics.isKept)
                Button("Reset Statistics…") { confirmsReset = true }
                    .disabled(!statistics.isKept)
            } footer: {
                Text("Only daily counts, never the words, kept on this Mac for 8 weeks. Turning statistics off deletes them.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset statistics?", isPresented: $confirmsReset) {
            Button("Reset", role: .destructive) { statistics.reset() }
        } message: {
            Text("Words fixed and time saved are deleted for every day.")
        }
    }

    private static func timeSaved(_ seconds: Double) -> Text {
        switch Statistics.TimeSaved(seconds: seconds) {
        case .seconds(let seconds): Text("≈ \(seconds) s")
        case .minutes(let minutes): Text("≈ \(minutes) min")
        case .hours(let hours, let minutes): Text("≈ \(hours) h \(minutes) min")
        }
    }
}

extension SettingsStore.Hotkey {
    var displayName: String {
        switch self {
        case .shift: String(localized: "Shift")
        case .option: String(localized: "Option")
        case .control: String(localized: "Control")
        case .command: String(localized: "Command")
        }
    }
}

extension Language {
    var displayName: String {
        switch self {
        case .english: String(localized: "English")
        case .russian: String(localized: "Russian")
        case .german: String(localized: "German")
        case .spanish: String(localized: "Spanish")
        }
    }
}
