// **The app's settings, in one window** — four panes chosen by icons at the top, as in the Mac’s
// own apps; each setting a row with its tile, its name, one line of what it does or where it stands,
// and the whole sentence on hover.

import AppKit
import Siliconed
import SwiftUI

/// **The settings window**: one per process, opened by « Settings… », or on the Macs by « Other Macs… ».
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    private let selection = SettingsSelection()

    /// The panes and their order are the library's (`SettingsPane`): `silicontrol settings` names them by the same words.
    typealias Pane = SettingsPane

    /// What the window shows, or would show when it opens: its pane, and the instruction of Prompt Lab's two menus.
    var shown: (pane: Pane, family: Family, gesture: PromptWriterInstructions.Gesture) {
        (selection.pane, selection.instructionFamily, selection.instructionGesture)
    }

    func refreshChrome() {
        window?.backgroundColor = Palette.columnInk
    }

    func show(_ app: AppState, pane: Pane? = nil) {
        if let pane { select(pane) }
        if let window {
            window.backgroundColor = Palette.columnInk
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: SettingsView.width, height: 420),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        w.titlebarAppearsTransparent = true
        w.titlebarSeparatorStyle = .none
        w.title = selection.pane.title
        w.backgroundColor = Palette.columnInk
        w.isReleasedWhenClosed = false
        // Incognito: no frame kept, nothing restored.
        w.isRestorable = false
        w.delegate = self
        window = w
        let host = NSHostingController(rootView: SettingsView(app: app, macs: MainWindow.shared.otherMacs, selection: selection))
        // The window follows the pane's height (`fit`), not the hosting view's guesses.
        host.sizingOptions = []
        w.contentViewController = host
        w.setContentSize(NSSize(width: SettingsView.width, height: 420))
        // The first layout reports the pane's height: sized before it is centered and shown, no jump.
        host.view.layoutSubtreeIfNeeded()
        if let pending { fit(pending) }
        w.center()
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    private var pending: CGFloat?

    /// **The window at the pane's height**, its top edge where it was, so that the tabs stay under the pointer;
    /// at most the screen's height (the pane scrolls then). Animated once shown.
    func fit(_ height: CGFloat) {
        guard let w = window, let content = w.contentView else { pending = height; return }
        pending = nil
        let chrome = w.frame.height - content.frame.height
        let room = (w.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let h = min(ceil(height), room - chrome - 40)
        guard abs(content.frame.height - h) > 0.5 else { return }
        let frame = NSRect(x: w.frame.minX, y: w.frame.maxY - (h + chrome), width: w.frame.width, height: h + chrome)
        w.setFrame(frame, display: true, animate: w.isVisible)
    }

    /// **Settings › Prompt Lab on one instruction**: the lab's mark opens it on the model it writes for; `silicontrol settings lab`
    /// too, a menu it does not name left as it is.
    func showInstruction(_ family: Family?, _ gesture: PromptWriterInstructions.Gesture?) {
        if let family { selection.instructionFamily = family }
        if let gesture { selection.instructionGesture = gesture }
        show(MainWindow.shared.local, pane: .lab)
    }

    func select(_ pane: Pane) {
        selection.pane = pane
        window?.title = pane.title
    }
}

extension SettingsPane: Identifiable {
    package var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .macs: String(localized: "Macs")
        case .lab: String(localized: "Prompt Lab")
        case .advanced: String(localized: "Advanced")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .macs: "desktopcomputer.and.macbook"
        case .lab: "sparkles"
        case .advanced: "slider.horizontal.3"
        }
    }
}

/// The pane shown, kept while the app runs — and, in Prompt Lab, the instruction shown.
@MainActor @Observable
final class SettingsSelection {
    var pane: SettingsWindow.Pane = .general
    var instructionFamily: Family = .zImage
    var instructionGesture: PromptWriterInstructions.Gesture = .rewrite
}

/// **What the window shows**: the chosen pane, on the column's ground.
struct SettingsView: View {
    static let width: CGFloat = 560
    @Bindable var app: AppState
    let macs: OtherMacs
    let selection: SettingsSelection
    /// Read again after an install: the link is the file system's, not the app's.
    @State private var command = SilicontrolCommand.state
    /// What the library weighs and what its disk has left, read off the main thread.
    @State private var modelBytes: Int?
    @State private var freeBytes: Int?

    /// The state the window shows: the Mac that computes, whose switch and map these are.
    private var shown: AppState { MainWindow.shared.carrier.mirror ?? app }

    var body: some View {
        let _ = StudioHub.shared.theme
        VStack(spacing: 0) {
            SettingsTabs(selection: selection).frame(height: SettingsTabs.height)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selection.pane {
                    case .general: general
                    case .macs: thisMac; OtherMacsSection(macs: macs)
                    case .lab: LabInstructionsPane(selection: selection)
                    case .advanced: advanced
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                .frame(width: Self.width, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    SettingsWindow.shared.fit($0 + SettingsTabs.height + 1)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Palette.column)
        .ignoresSafeArea(.container, edges: .top)
    }

    // ── General ──

    @ViewBuilder private var general: some View {
        SettingsGroup("Studio") {
            studioAppearance
            ambientBacklight
            acceleratorsRow
            if app.fasterRenderingBeta { fasterRenderingRow }
        }
        SettingsGroup("Models") { library }
            .help("Where the installed models and LoRAs live. Remove them in the Models window, not the Finder.")
            .task(id: "\(app.library.root.path) \(app.forgeInProgress ?? "") \(app.libraryReachable)") {
                let library = app.library
                let figures = await Task.detached(priority: .utility) {
                    (Library.size(library.root.appendingPathComponent("store").resolvingSymlinksInPath().path), library.freeSpace())
                }.value
                (modelBytes, freeBytes) = figures
            }
        SettingsGroup("Images") { everyImage }
    }

    private var studioAppearance: some View {
        let hub = StudioHub.shared
        return SettingRow(Text("Studio Theme"), Text(hub.theme.subtitle),
                          detail: "Changes Siliconed’s darkroom surfaces, specular highlights and primary call-to-action glow.") {
            IconTile(symbol: "paintpalette.fill", color: Palette.live, side: 26)
        } trailing: {
            EmptyView()
        } below: {
            HStack(spacing: 8) {
                ForEach(StudioTheme.allCases) { theme in
                    let active = hub.theme == theme
                    Button {
                        withAnimation(Motion.pick(.easeOut(duration: 0.18))) {
                            hub.theme = theme
                        }
                    } label: {
                        HStack(spacing: 6) {
                            HStack(spacing: -3) {
                                ForEach(Array(theme.swatchHexes.enumerated()), id: \.offset) { _, hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                                }
                            }
                            Text(theme.title)
                                .font(.caption.weight(active ? .semibold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(active ? Palette.live.opacity(0.18) : Color.primary.opacity(0.06))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(active ? Palette.live.opacity(0.8) : Palette.hairline, lineWidth: active ? 1.3 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ambientBacklight: some View {
        SettingRow(Text("Ambient Backlight"),
                   Text("Softly illuminates the canvas background with colors sampled from the current image.")) {
            IconTile(symbol: "sparkles.rectangle.stack.fill", color: Palette.control, side: 26)
        } trailing: {
            SettingSwitch("Ambient Backlight", isOn: Bindable(StudioHub.shared).ambientBacklight)
        }
    }

    private var acceleratorsRow: some View {
        let id = app.identifier
        let reason = DiTSwitches.acceleratorsUnavailable(measured: app.settingsRead, offered: app.acceleratorsOffered)
        let helpText = reason.map(AcceleratorWords.unavailable) ?? AcceleratorWords.switchHelp(app.acceleratorOffer ?? .none)
        return SettingRow(Text("Accelerators"), Text(verbatim: helpText)) {
            IconTile(symbol: "cpu.fill", color: Palette.peach, side: 26)
        } trailing: {
            SettingSwitch("Accelerators", isOn: Binding(get: { reason == nil && app.accelerators(for: id) },
                                                        set: { app.setAccelerators($0, for: id) }))
                .disabled(reason != nil)
        }
    }

    private var fasterRenderingRow: some View {
        let form = shown
        let unavailable = form.fasterRenderingUnavailable
        let subtitle = unavailable.map(DiTBox.sentence)
            ?? String(localized: "From 1024² up, the first steps at half size: faster, a slightly different image.")
        return SettingRow(Text("Faster Rendering"), Text(verbatim: subtitle)) {
            IconTile(symbol: "hare.fill", color: Palette.sky, side: 26)
        } trailing: {
            SettingSwitch("Faster Rendering", isOn: Binding(get: { form.fasterRenderingShown(for: form.identifier) },
                                                            set: { on in
                                                                app.setFasterRendering(on, for: form.identifier)
                                                                if form !== app { form.setFasterRendering(on, for: form.identifier) }
                                                            }))
                .disabled(unavailable != nil)
        }
    }

    /// **Where the models live**: moved to another disk (the internal SSD is precious), opened there,
    /// brought back — each said with what happens (`AppState+Place.swift`).
    private var library: some View {
        let elsewhere = app.libraryIsElsewhere
        return SettingRow(Text(elsewhere ? "On Another Disk" : "On This Mac"), figures,
                          detail: elsewhere
                              ? "On another disk: what a render reads is copied to this Mac first, once per session, and removed when Siliconed quits. The disk must be connected to render."
                              : "On this Mac. To free its disk, move the library to another one — an external disk, a network share: Siliconed then copies to this Mac only the model it renders, for the session.") {
            IconTile(symbol: elsewhere ? "externaldrive.fill" : "internaldrive.fill", color: Palette.sky, side: 26)
        } trailing: {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.library.root]) }
                .disabled(!app.libraryReachable)
        } below: {
            Text(verbatim: app.library.displayPath).font(.caption).foregroundStyle(.tertiary)
                .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            if !app.libraryReachable {
                Text(app.libraryBlocker ?? "").font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Move Library…") { app.chooseLibraryDestination() }
                    .disabled(!app.managementPossible)
                    .help("Copies the library to the folder you choose, checks every file, then removes it from here. The licenses you accepted and this Mac’s settings stay on this Mac")
                Button("Open Library…") { app.chooseLibraryToOpen() }
                    .disabled(app.forgeInProgress != nil || app.busy)
                    .help("Uses a library that is already somewhere else, another disk’s for instance. Nothing is moved")
            }
            if elsewhere {
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
    }

    /// What the library weighs, and what is left beside it.
    private var figures: Text? {
        guard app.libraryReachable, let free = freeBytes.map(Figures.disk) else { return nil }
        guard let models = modelBytes, models > 0 else { return Text("\(free) free") }
        return Text("\(Figures.disk(models)) of models · \(free) free")
    }

    /// **Incognito & Save Every Image To…**: saved by default to `Downloads › Siliconed`; Incognito keeps new images in memory only.
    private var everyImage: some View {
        let every = EveryImage.shared
        let subtitle: Text = app.incognito
            ? Text("New images stay in memory until you save them.")
            : (every.folder.map { Text(verbatim: Library.withoutHome($0.path)) }
               ?? Text("Each new image, as a PNG with its prompt, seed and model."))
        return SettingRow(Text("Incognito"), subtitle,
                          detail: "New images stay in memory until you save them. When this is off, each new image is also saved as a PNG, with its prompt, seed and model, in Downloads › Siliconed.") {
            IconTile(symbol: app.incognito ? "eye.slash.fill" : "photo.on.rectangle.angled", color: Palette.rose, side: 26)
        } trailing: {
            SettingSwitch("Incognito", isOn: $app.incognito)
        } below: {
            if let folder = every.folder {
                HStack {
                    Button("Change Folder…") { every.choose() }
                    Button("Show in Finder") {
                        if folder.path == EveryImage.downloads.path {
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        }
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                }
            }
        }
    }

    // ── Macs ──

    private static let machine = EngineSettings.Machine.detected()

    /// **This Mac**: what it is, and the measure its renders are planned from — the lender's, while computing on it.
    private var thisMac: some View {
        SettingsGroup("This Mac") {
            SettingRow(Text(verbatim: macs.name),
                       Text(verbatim: [Self.machine.chip, Figures.memory(Self.machine.ramBytes)].joined(separator: " · "))) {
                MacIcon(hardwareModel: Self.machine.hardwareModel).frame(width: 30, height: 30)
            } trailing: {
                EmptyView()
            }
            SettingRow(Text("Measure"), Text(measureLine), detail: DiagnosticSheet.mapStatus(shown)) {
                IconTile(symbol: "gauge.with.dots.needle.67percent", color: shown.mapMeasured ? Palette.sky : .orange, side: 26)
            } trailing: {
                Button("Measure This Mac…") {
                    MainWindow.shared.show()
                    shown.openDiagnostic()
                }
                .help("About a minute, five at most; done before the first render and after each update. A new measure applies to the next render.")
            } below: {
                if let name = shown.mirror?.macName {
                    Text("This measures “\(name)”, the Mac that computes for you.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The measure in a few words; the sentence (`DiagnosticSheet.mapStatus`) on hover.
    private var measureLine: LocalizedStringKey {
        let map = shown.mapFacts
        if let stored = map.stored, stored.current {
            let day = DiagnosticSheet.day(stored.date)
            return map.inUse == nil || map.inUse == stored ? "Measured on \(day)" : "Measured on \(day); applies to the next render"
        }
        if map.stored != nil { return "To measure again: macOS or Siliconed changed" }
        return "Not measured yet"
    }

    // ── Advanced ──

    @ViewBuilder private var advanced: some View {
        SettingsGroup("Command Line") {
            SettingRow(Text(verbatim: "silicontrol"), commandLine,
                       detail: "silicontrol drives this app from a terminal, a script or an AI agent. See: silicontrol help") {
                IconTile(symbol: "terminal.fill", color: Palette.control, side: 26)
            } trailing: {
                Button(command == .installed ? "Reinstall…" : "Install…") {
                    SilicontrolCommand.install()
                    command = SilicontrolCommand.state
                }
            }
        }
        SettingsGroup(footer: "Off by default; they may change.") {
            BetaBadge(help: "Beta: still being settled, and may change.")
        } content: {
            beta("More Solvers", "Euler a, DPM++ 2M and UniPC, beside Euler.", symbol: "function", color: Palette.peach,
                 detail: "Adds the solvers Euler a, DPM++ 2M and UniPC to the DiT’s box and to the series. The default, Euler, is the one the models were distilled for.",
                 isOn: $app.developerMode)
            beta("Choose Steps", "The step count, for step-distilled LoRAs.", symbol: "stairs", color: Palette.live,
                 detail: "Adds the steps to the DiT’s box. The models are distilled for 8; fewer suits a LoRA distilled to fewer steps, such as a 4-step one. Off, every render takes the model’s own count.",
                 isOn: $app.stepsBeta)
            beta("Faster Rendering", "From 1024², the first steps at half size.", symbol: "hare.fill", color: Palette.sky,
                 detail: "Adds a Faster Rendering switch to the DiT’s box: from 1024² up, the first steps at half size, faster, a slightly different image. Not with a LoRA, Detail or an edit. Off, no render is a faster one.",
                 isOn: $app.fasterRenderingBeta)
            beta("Size in Two Scales", "A proportion, then 1K or 2K.", symbol: "aspectratio.fill", color: Palette.rose,
                 detail: "Splits the Size menu of the rack in two: a proportion, then a resolution, 1K (about 1 megapixel) or 2K (about 4). The sizes are the app’s; the pencil still types any other.",
                 isOn: $app.sizeScalesBeta)
            beta("Negative LoRA Strengths", "From −1.5 to 1.5, for slider LoRAs.", symbol: "plusminus", color: Palette.control,
                 detail: "Lets a LoRA’s strength go from −1.5 to 1.5, for “slider” LoRAs. An ordinary LoRA is damaged by a negative strength.",
                 isOn: $app.negativeLoRAStrengths)
        }
    }

    private var commandLine: Text {
        switch command {
        case .installed: Text("Installed: \(SilicontrolCommand.destination)")
        case .otherCopy: Text("\(SilicontrolCommand.destination) points to another copy of Siliconed.")
        case .absent: Text("Not installed.")
        }
    }

    private func beta(_ title: LocalizedStringKey, _ line: LocalizedStringKey, symbol: String, color: Color,
                      detail: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        SettingRow(Text(title), Text(line), detail: detail) {
            IconTile(symbol: symbol, color: color, side: 26)
        } trailing: {
            SettingSwitch(title, isOn: isOn)
        }
    }
}

// MARK: - The parts

/// **The tabs**, under the window's title: a glyph and its name, the chosen one in the chart's indigo on a recess.
/// The band moves the window, as a title bar does.
struct SettingsTabs: View {
    static let height: CGFloat = 92
    let selection: SettingsSelection

    var body: some View {
        ZStack {
            WindowDragArea()
            HStack(spacing: 4) {
                ForEach(SettingsWindow.Pane.allCases) { pane in
                    let chosen = selection.pane == pane
                    Button { SettingsWindow.shared.select(pane) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: pane.symbol).font(.system(size: 19, weight: .regular)).frame(height: 24)
                            Text(verbatim: pane.title).font(.system(size: 11, weight: chosen ? .semibold : .regular))
                        }
                        .frame(minWidth: 64)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .foregroundStyle(chosen ? Palette.live : Color.secondary)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(chosen ? Palette.well : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: pane.title))
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .padding(.top, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// **A group of settings**: its name above, its rows on one card a step above the ground, a line between
/// two rows; a footnote under it if it needs one.
struct SettingsGroup<Header: View, Content: View>: View {
    let footer: LocalizedStringKey?
    let header: Header
    let content: Content

    init(footer: LocalizedStringKey? = nil, @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.footer = footer
        self.header = header()
        self.content = content()
    }

    var body: some View {
        let card = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            header.font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 12)
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id { Divider().padding(.leading, 52) }
                        row
                    }
                }
            }
            .background(Palette.surface, in: card)
            .overlay(card.strokeBorder(Palette.hairline))
            if let footer {
                Text(footer).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension SettingsGroup where Header == Text {
    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.init(footer: footer, header: { Text(title) }, content: content)
    }
}

/// **A setting**: its tile, its name, one line of what it does or where it stands, its control at the right;
/// under them what it opens (a path, buttons). The whole sentence on hover (`detail`).
struct SettingRow<Leading: View, Trailing: View, Below: View>: View {
    let title: Text
    let subtitle: Text?
    let detail: LocalizedStringKey?
    let leading: Leading
    let trailing: Trailing
    let below: Below

    init(_ title: Text, _ subtitle: Text? = nil, detail: LocalizedStringKey? = nil,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing, @ViewBuilder below: () -> Below) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.leading = leading()
        self.trailing = trailing()
        self.below = below()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                leading.frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    title
                    if let subtitle {
                        subtitle.font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .detail(detail)
                trailing
            }
            VStack(alignment: .leading, spacing: 8) { below }
                .padding(.leading, 40)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

extension SettingRow where Below == EmptyView {
    init(_ title: Text, _ subtitle: Text? = nil, detail: LocalizedStringKey? = nil,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, subtitle, detail: detail, leading: leading, trailing: trailing, below: { EmptyView() })
    }
}

/// **A switch**, small as in the system's settings, in the chart's indigo; its name for VoiceOver only, the row shows it.
struct SettingSwitch: View {
    let title: LocalizedStringKey
    let isOn: Binding<Bool>
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) { self.title = title; self.isOn = isOn }

    var body: some View {
        Toggle(isOn: isOn) { Text(title) }
            .toggleStyle(.switch).controlSize(.small).labelsHidden()
            .tint(Palette.control)
    }
}

/// **A connection's state**, a dot before its words: what runs when connected, orange on the way, red refused.
struct LinkState: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(verbatim: text)
        }
    }
}

private extension View {
    @ViewBuilder func detail(_ key: LocalizedStringKey?) -> some View {
        if let key { help(key) } else { self }
    }
}
