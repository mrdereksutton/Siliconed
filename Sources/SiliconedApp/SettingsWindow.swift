// **The app's settings, in one window** — three tabs, named by what one comes to do; each switch with
// what it does, said under it.
//
//     Siliconed ▸ Settings… (⌘,)
//     ┌──────────────────────────────────────────────────────┐
//     │        [ General ]  Other Macs   Advanced             │
//     │ ┌──────────────────────────────────────────────────┐ │
//     │ │ Models             where the library is, shown in │ │
//     │ │                    the Finder; moved to another   │ │
//     │ │                    disk, opened, brought back     │ │
//     │ └──────────────────────────────────────────────────┘ │
//     └──────────────────────────────────────────────────────┘
//
//     General     what an everyday user touches: the library; Save Every Image To… (off by default: `EveryImage`).
//     Other Macs  lend this Mac, compute on another (`OtherMacsView.swift`).
//     Advanced    kept out of the way: This Mac (the capacity map, measured only when asked), Command
//                 Line (silicontrol, linked into /usr/local/bin), Beta (More Solvers, Faster Rendering,
//                 Size in Two Scales, Negative LoRA Strengths: off by default, may change; named subjects moved to the Prompt Lab).
//                 ┌ This Mac ───── [Measure This Mac…]
//                 ├ Command Line ─ [Install…]
//                 └ Beta ───────── More Solvers · Faster Rendering · Size in Two Scales · Negative LoRA Strengths
//
// - **Incognito**: an NSWindow of ours, as `MainWindow` — not SwiftUI's `Settings` scene, which would
//   keep its frame; not restorable. What it sets are the app's preferences (`AppState`'s header), the
//   same keys as before: a switch moved here keeps its value.
// - **A switch changes what it changes at once**, as from the menu it replaces: More Solvers off takes
//   the solver and a solver axis with it (`AppState.developerMode`, whose key keeps its old name).
// - How two images are compared (curtain, switch, side by side) is set under the image, where it is
//   used (`CurtainSwitch`), and remembered.
// - **The capacity map is measured from the sheet**, on the main window (`DiagnosticSheet`): this
//   window says where the session stands and opens it.

import AppKit
import Siliconed
import SwiftUI

/// **The settings window**: one per process, opened by « Settings… ».
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(_ app: AppState) {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(app: app, macs: MainWindow.shared.otherMacs)
        let host = NSHostingController(rootView: view)
        host.sizingOptions = [.preferredContentSize]
        let w = NSWindow(contentViewController: host)
        w.title = String(localized: "Settings")
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        // Incognito: no frame kept, nothing restored.
        w.isRestorable = false
        w.delegate = self
        // The hosting controller sizes the window at its first layout: centered before, it would
        // grow from the left edge and run off to the right.
        host.view.layoutSubtreeIfNeeded()
        w.setContentSize(host.view.fittingSize)
        w.center()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }
}

/// **What the window shows**: three tabs, each switch with its sentence.
struct SettingsView: View {
    @Bindable var app: AppState
    let macs: OtherMacs
    /// Read again after an install: the link is the file system's, not the app's.
    @State private var command = SilicontrolCommand.state

    /// The state the window shows: the Mac that computes, whose switch and map these are.
    private var shown: AppState { MainWindow.shared.carrier.mirror ?? app }

    /// Fork: the pane shown — on Silicon's capsule tabs, as the main window's modes.
    private enum Pane: CaseIterable { case general, otherMacs, advanced }
    @State private var pane = Pane.general

    var body: some View {
        // A fixed frame: the window keeps one size from one pane to the next, so that it never jumps
        // under the pointer. A pane longer than this scrolls.
        VStack(spacing: 0) {
            CapsuleTabs(selection: $pane, tabs: Pane.allCases) { pane in
                switch pane {
                case .general: "General"
                case .otherMacs: "Other Macs"
                case .advanced: "Advanced"
                }
            }
            .fixedSize()
            .padding(.top, 12)
            .padding(.bottom, 2)
            Group {
                switch pane {
                case .general: general
                case .otherMacs: Form { OtherMacsSection(macs: macs) }.formStyle(.grouped)
                case .advanced: advanced
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 540)
        // Fork: the window in Siliconed's own materials — graphite, Silicon's switches and buttons.
        .scrollContentBackground(.hidden)
        .background(WaferBackground())
        .toggleStyle(SiliconToggleStyle())
        .buttonStyle(SiliconButtonStyle())
    }

    /// What one comes for: where the models are.
    private var general: some View {
        Form {
            Section {
                // Fork: the DiT box's two switches (`DiTBox.switches`) live here — the window never draws the rack. Each is the
                // selected model's; one that cannot apply is greyed and says why.
                let id = app.identifier
                let reason = DiTSwitches.acceleratorsUnavailable(measured: app.settingsRead, offered: app.acceleratorsOffered)
                Toggle(isOn: Binding(get: { reason == nil && app.accelerators(for: id) }, set: { app.setAccelerators($0, for: id) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accelerators")
                        Text(verbatim: reason.map(AcceleratorWords.unavailable) ?? AcceleratorWords.switchHelp(app.acceleratorOffer ?? .none))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(reason != nil)
                // Faster Rendering is a Beta option (Advanced): no switch without it.
                // Faster Rendering rides on each job: read from the state the composer renders from (another Mac's mirror when
                // computing there), written to it and to this Mac's preference.
                if app.fasterRenderingBeta {
                    let form = shown
                    let unavailable = form.fasterRenderingUnavailable
                    Toggle(isOn: Binding(get: { form.fasterRenderingShown(for: form.identifier) },
                                         set: { on in
                                             app.setFasterRendering(on, for: form.identifier)
                                             if form !== app { form.setFasterRendering(on, for: form.identifier) }
                                         })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Faster Rendering")
                            Text(verbatim: unavailable.map(Self.sentence)
                                 ?? String(localized: "From 1024² up, the first steps at half size: faster, a slightly different image."))
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .disabled(unavailable != nil)
                }
            }
            // Fork: saved by default to Downloads › Siliconed; Incognito keeps images in memory only (`EveryImage`).
            Section {
                Toggle(isOn: $app.incognito) {
                    SettingLabel("Incognito", "New images stay in memory until you save them. When this is off, each new image is also saved as a PNG, with its prompt, seed and model, in Downloads › Siliconed.")
                }
                if let folder = EveryImage.shared.folder {
                    LabeledContent {
                        Button("Show in Finder") {
                            if folder.path == EveryImage.downloads.path {
                                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            }
                            NSWorkspace.shared.activateFileViewerSelecting([folder])
                        }
                    } label: {
                        Text(verbatim: folder.path(percentEncoded: false)).font(.caption).textSelection(.enabled)
                    }
                }
            }
            Section {
                LabeledContent {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.library.root]) }
                        .disabled(!app.libraryReachable)
                } label: {
                    SettingLabel("Models", "Where the installed models and LoRAs live. Remove them in the Models window, not the Finder.")
                }
                Text(verbatim: app.library.displayPath).font(.caption).textSelection(.enabled)
                library
            }
        }
        .formStyle(.grouped)
    }

    /// Why Faster Rendering would do nothing for this render, in a sentence (`DiTBox.sentence`).
    private static func sentence(_ reason: DiTSwitchUnavailable) -> String {
        switch reason {
        case .sizeUnder1024: String(localized: "Needs 1024 px or more on each side.")
        case .withLoRADetailOrEdit: String(localized: "Not with a LoRA, Detail or an edit.")
        case .stepsOffRecipe: String(localized: "Only at the model’s own step count.")
        case .notMeasured, .noAccelerator: AcceleratorWords.unavailable(reason)
        }
    }

    /// Out of the everyday way: the capacity map that renders are planned from, the terminal, then what
    /// is still in beta.
    private var advanced: some View {
        Form {
            Section {
                LabeledContent {
                    Button("Measure This Mac…") {
                        MainWindow.shared.show()
                        shown.openDiagnostic()
                    }
                } label: {
                    SettingLabel("This Mac", "About a minute, five at most; done before the first render and after each update. A new measure applies to the next render.")
                }
                if let name = shown.mirror?.macName {
                    Text("This measures “\(name)”, the Mac that computes for you.").font(.caption)
                }
                Text(DiagnosticSheet.mapStatus(shown)).font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                LabeledContent {
                    Button(command == .installed ? "Reinstall…" : "Install…") {
                        SilicontrolCommand.install()
                        command = SilicontrolCommand.state
                    }
                } label: {
                    SettingLabel("Command Line", "silicontrol drives this app from a terminal, a script or an AI agent. See: silicontrol help")
                }
                Group {
                    switch command {
                    case .installed: Text("Installed: \(SilicontrolCommand.destination)").textSelection(.enabled)
                    case .otherCopy: Text("\(SilicontrolCommand.destination) points to another copy of Siliconed.")
                    case .absent: Text("Not installed.")
                    }
                }
                .font(.caption)
            }
            Section {
                Toggle(isOn: $app.developerMode) {
                    SettingLabel("More Solvers", "Adds the solvers Euler a, DPM++ 2M and UniPC to Generate’s settings and to the exploration’s axes. The default, Euler, is the one the models were distilled for.")
                }
                Toggle(isOn: $app.fasterRenderingBeta) {
                    SettingLabel("Faster Rendering", "Adds a Faster Rendering switch to General: from 1024² up, the first steps at half size, faster, a slightly different image. Not with a LoRA, Detail or an edit. Off, no render is a faster one.")
                }
                // Fork: no « Size in Two Scales »: the composer always picks a ratio, then 1K or 2K (`SizeTable`).
                Toggle(isOn: $app.negativeLoRAStrengths) {
                    SettingLabel("Negative LoRA Strengths", "Lets a LoRA’s strength go from −1.5 to 1.5, for “slider” LoRAs. An ordinary LoRA is damaged by a negative strength.")
                }
            } header: {
                HStack(spacing: 8) {
                    BetaBadge(help: "Beta: still being settled, and may change.")
                    Text("Off by default; they may change.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// **Where the models live**: moved to another disk (the internal SSD is precious), opened there,
    /// brought back — each said with what happens (`AppState+Place.swift`).
    @ViewBuilder private var library: some View {
        if !app.libraryReachable {
            Text(app.libraryBlocker ?? "").font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else if app.libraryIsElsewhere {
            explanation("On another disk: what a render reads is copied to this Mac first, once per session, and removed when Siliconed quits. The disk must be connected to render.")
        } else {
            explanation("On this Mac. To free its disk, move the library to another one — an external disk, a network share: Siliconed then copies to this Mac only the model it renders, for the session.")
        }
        HStack {
            Button("Move Library…") { app.chooseLibraryDestination() }
                .disabled(!app.managementPossible)
                .help("Copies the library to the folder you choose, checks every file, then removes it from here. The licenses you accepted and this Mac’s settings stay on this Mac")
            Button("Open Library…") { app.chooseLibraryToOpen() }
                .disabled(app.forgeInProgress != nil || app.busy)
                .help("Uses a library that is already somewhere else, another disk’s for instance. Nothing is moved")
        }
        if app.libraryIsElsewhere {
            HStack {
                Button("Move Back to This Mac") { app.moveLibraryHome() }
                    .disabled(!app.managementPossible)
                Button("Use This Mac’s Library") { app.useLocalLibrary() }
                    .disabled(app.forgeInProgress != nil || app.busy)
                    .help("Renders with what this Mac holds — maybe nothing yet. The library on the other disk is not touched")
            }
        }
        if let title = app.forgeInProgress {
            Text(ForgeProgress.line(app.forgeJournal).map { "\(title) — \($0)" } ?? title)
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func explanation(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// **A setting's name, and under it what it does** — in the Settings' tabs and in the Other Macs section.
struct SettingLabel: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    init(_ title: LocalizedStringKey, _ text: LocalizedStringKey) { self.title = title; self.text = text }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
