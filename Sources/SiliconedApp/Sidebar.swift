// **The window's left column: the rack, and under it what the chain is doing** — plus the Studio
// composer's reference strip and floating activity card when the rack is folded away.

import AppKit
import ImageIO
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

/// The window's primary workspaces, switched in `StudioHeaderBar`:
/// `.generate` (Studio canvas + bottom `Composer`) and `.explore` (Signal-Chain Rack + Series bracketing).
enum SidebarTab: Hashable { case generate, explore }

struct Sidebar: View {
    @Bindable var app: AppState
    @State private var chainAway = false

    var body: some View {
        let _ = StudioHub.shared.theme
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    RackView(app: app, chainAway: $chainAway)
                }
                .scrollIndicators(.automatic)
                // Once the chain's boxes have scrolled away (setting the DiT, its LoRAs), the chain stays in sight in small,
                // lit as they are; a click scrolls back to them (`RackMiniChain.swift`).
                .overlay(alignment: .top) {
                    if chainAway {
                        Button { withAnimation(Motion.pick(.easeOut(duration: 0.3))) { proxy.scrollTo(RackView.top, anchor: .top) } } label: {
                            MiniChain(app: app)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Palette.column)
                                .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("The chain, while the rack scrolls: a click brings its boxes back")
                        .transition(.opacity)
                    }
                }
                .animation(Motion.pick(.easeOut(duration: 0.2)), value: chainAway)
                // `silicontrol rack top|dit`: the scroll the hand would make.
                .onChange(of: app.rackScroll?.count) {
                    guard let place = app.rackScroll?.place else { return }
                    withAnimation(Motion.pick(.easeOut(duration: 0.3))) {
                        proxy.scrollTo(place == .top ? RackView.top : RackView.dit, anchor: .top)
                    }
                }
            }
            Footer(app: app)
        }
        .background(Palette.column)
        // A `.safetensors` or a `.gguf` dropped on the column is imported (model or LoRA).
        .dropDestination(for: URL.self) { urls, _ in
            let s = urls.filter(AppState.importable)
            guard !s.isEmpty, app.importPossible else { return false }
            app.perform(s)
            return true
        }
    }
}

extension AppState {
    /// The floating Studio activity card shows only when it has something to say while the Rack is closed.
    var activityShows: Bool {
        if case .running = diagnostic { return true }
        return !file.isEmpty || (othersQueued > 0 && mirror != nil) || copying != nil || forgeInProgress != nil
            || problem != nil || journalLine != nil || !settingsLines.isEmpty
    }

    // MARK: Studio Composer Input Helpers (bridged onto v0.21 `AppState.inputs`)

    func chooseReferences() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK else { return }
        addReferences(panel.urls)
    }

    func addReferences(_ urls: [URL]) {
        for url in urls {
            guard canAddReference, nextReferenceRefusal() == nil else { break }
            guard let image = read(url) else { continue }
            let role: LabInputs.Role = editInputs.isEmpty ? .edited : .reference
            addInput(image, role: role)
        }
    }

    func addReference(png data: Data) {
        guard canAddReference, nextReferenceRefusal() == nil,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        let thumb = FinishedImage.reduce(cg, side: 240) ?? cg
        let image = ReferenceImage(
            source: .bytes(data),
            vignette: NSImage(cgImage: thumb, size: .zero),
            name: String(localized: "pasted image"),
            width: cg.width,
            height: cg.height
        )
        let role: LabInputs.Role = editInputs.isEmpty ? .edited : .reference
        addInput(image, bytes: data, role: role)
    }

    func removeReference(_ id: ReferenceImage.ID) {
        guard let i = inputIndex(shown: id) else { return }
        let wasEdited = inputs[i].role == .edited
        removeInput(inputs[i].id)
        if wasEdited, let nextRef = inputs.firstIndex(where: { $0.role == .reference }) {
            inputs[nextRef].role = .edited
        }
    }

    func moveReference(_ id: ReferenceImage.ID, to destination: Int) {
        var current = editInputs.map(\.shown)
        guard let from = current.firstIndex(where: { $0.id == id }) else { return }
        let to = min(max(0, destination), current.count - 1)
        guard from != to else { return }
        let moved = current.remove(at: from)
        current.insert(moved, at: to)
        setEditImages(current)
    }

    func moveReference(_ id: ReferenceImage.ID, by delta: Int) {
        let current = editInputs.map(\.shown)
        guard let from = current.firstIndex(where: { $0.id == id }) else { return }
        moveReference(id, to: from + delta)
    }

    func chooseStartReplacement() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        replaceStart(with: url)
    }

    func replaceStart(with url: URL) {
        guard let image = startImage(file: url) else { return }
        carryStart(image)
    }
}

/// **A size typed by hand**, judged by the engine's own rules before it is taken.
struct CustomSize: View {
    let app: AppState
    var title: LocalizedStringKey = "Size"
    var done: (() -> Void)? = nil
    @State private var text = ""
    @State private var refusal: Problem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("Size", text: $text, prompt: Text(verbatim: "832x1216"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 140)
                    .onSubmit(apply)
                Button("Use", action: apply)
                    .keyboardShortcut(.defaultAction)
                    .tint(Palette.control)
            }
            if let refusal {
                Text(refusal.title).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Width × height: each side from 512 to \(String(app.formatMaximumSide)) and a multiple of \(String(app.formatMultiple)).")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(minWidth: 280, alignment: .leading)
        .onAppear { text = "\(app.format.width)x\(app.format.height)" }
    }

    private func apply() {
        refusal = app.setCustomFormat(text)
        guard refusal == nil else { return }
        if let done { done() } else { dismiss() }
    }
}

/// **A reference's thumbnail** in the Studio Composer: its number (the one the prompt says), the image,
/// and on hover a button to crop or remove it. Cited `@subjects` appear alongside edit images with an `@` badge.
struct ReferenceThumbnail: View {
    static let side: CGFloat = 60
    let app: AppState
    let reference: ReferenceImage
    let number: Int
    let last: Bool
    @State private var hover = false
    @State private var target = false

    private static let prefix = "siliconed-reference:"

    private var isDirectInput: Bool { app.inputIndex(shown: reference.id) != nil }

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: reference.vignette).resizable().scaledToFill()
                .frame(width: Self.side, height: Self.side)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(target ? Palette.live : Palette.hairline,
                                  lineWidth: target ? 2 : 1))
                .overlay(alignment: .topLeading) {
                    Text(verbatim: "\(number)")
                        .font(.caption2.weight(.bold)).monospacedDigit()
                        .foregroundStyle(number == 1 ? Palette.onLive : .white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(number == 1 ? Palette.live : Color.black.opacity(0.65)))
                        .padding(4)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isDirectInput, hover, app.cropRefusal(width: reference.width, height: reference.height) == nil {
                        Button { app.beginCrop(reference) } label: {
                            Image(systemName: "crop").font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.black.opacity(0.65)))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .help("Crop this image (the frame keeps at least \(String(Format.minimumSide)) px a side)")
                        .accessibilityLabel(Text("Crop…"))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isDirectInput, hover {
                        Button { app.removeReference(reference.id) } label: {
                            Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .frame(width: 24, height: 24).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .help("Remove")
                        .accessibilityLabel(Text("Remove"))
                    }
                }
            Text(isDirectInput
                 ? (number == 1 ? String(localized: "edited") : String(localized: "image \(number)"))
                 : reference.name)
                .font(.caption2)
                .foregroundStyle(number == 1 || !isDirectInput ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: Self.side + 8)
        }
        .onHover { hover = $0 }
        .help(Text(verbatim: "\(reference.name) · \(reference.width) × \(reference.height)"))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(number). \(reference.name)"))
        .draggable(Self.prefix + reference.id.uuidString) {
            Image(nsImage: reference.vignette).resizable().scaledToFit().frame(width: 48, height: 48)
        }
        .dropDestination(for: String.self) { items, _ in
            guard isDirectInput,
                  let item = items.first, item.hasPrefix(Self.prefix),
                  let id = UUID(uuidString: String(item.dropFirst(Self.prefix.count))),
                  app.inputIndex(shown: id) != nil else { return false }
            app.moveReference(id, to: number - 1)
            return true
        } isTargeted: { target = $0 && isDirectInput }
        .contextMenu {
            if isDirectInput {
                let editCount = app.editInputs.count
                if number > 1 {
                    Button("Make It Image 1") { app.moveReference(reference.id, to: 0) }
                    Button("Move Left") { app.moveReference(reference.id, by: -1) }
                }
                if number < editCount {
                    Button("Move Right") { app.moveReference(reference.id, by: 1) }
                }
                Divider()
                Button("Crop…") { app.beginCrop(reference) }
                    .disabled(app.cropRefusal(width: reference.width, height: reference.height) != nil)
                Button("Replace…") { app.replaceReference(reference.id) }
                Button("Remove", role: .destructive) { app.removeReference(reference.id) }
            }
        }
    }
}

// MARK: - Under the rack & over the composer: the queue, what goes on, what went wrong

/// **Under the rack** when the Signal-Chain sidebar is visible.
struct Footer: View {
    @Bindable var app: AppState

    private var speaks: Bool {
        if case .running = app.diagnostic { return true }
        return app.busy || app.othersQueued > 0 || app.copying != nil || app.forgeInProgress != nil || app.problem != nil
            || app.journalLine != nil || !app.settingsLines.isEmpty
    }

    var body: some View {
        if speaks {
            ActivityStatusContents(app: app, showsRunningJob: true)
                .padding(14)
                .background(Palette.column)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

/// **Over the Studio Composer** when the Rack sidebar is folded away.
struct ActivityCard: View {
    @Bindable var app: AppState

    var body: some View {
        ActivityStatusContents(app: app, showsRunningJob: !app.file.isEmpty)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .studioCard(cornerRadius: 18)
    }
}

private struct ActivityStatusContents: View {
    @Bindable var app: AppState
    let showsRunningJob: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case let .running(done, total, line) = app.diagnostic {
                Text(app.settingsRead ? "The diagnostic is running: renders wait for it."
                                      : "Siliconed measures this Mac before its first render — about a minute.")
                    .font(.callout)
                Text(verbatim: "\(line) · \(done + 1)/\(total)").font(.caption).foregroundStyle(.secondary)
            }
            if showsRunningJob ? app.busy : !app.file.isEmpty {
                queue
            }
            if app.othersQueued > 0, let mirror = app.mirror {
                Label(app.othersSeconds.map { s in
                    String(localized: "Renders for others on “\(mirror.macName)”: \(app.othersQueued), about \(Duration.seconds(s).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated)))")
                } ?? String(localized: "Renders for others on “\(mirror.macName)”: \(app.othersQueued)"),
                      systemImage: "person.2")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let c = app.copying {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title).font(.callout).lineLimit(2)
                    ProgressView(value: c.fraction).controlSize(.small)
                }
                .help("The library is on another disk: what a render reads is copied to this Mac first, once, and removed when Siliconed quits")
            }
            if let title = app.forgeInProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(title).font(.callout).lineLimit(2)
                        Spacer()
                        Button("Stop") { app.cancelForge() }
                            .buttonStyle(.chartLink).font(.caption)
                            .help("Stops the installation: the files already downloaded are kept, the one in progress will start over")
                    }
                    if let line = app.forgeLine {
                        Text(line).font(.caption).monospacedDigit().foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .help(app.forgeHelp)
            }
            if let problem = app.problem {
                ProblemView(problem: problem) { app.problem = nil }
            }
            if let line = app.journalLine {
                Label(line, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .help(app.journal.joined(separator: "\n"))
            }
            ForEach(Array(zip(app.settingsLines, app.settingsWarnings)), id: \.1) { line, raw in
                Label(line, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .help(raw)
            }
        }
    }

    private var queue: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let job = app.currentJob { running(job) }
            if !app.file.isEmpty { waiting }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.well))
    }

    private func running(_ job: Job) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                .foregroundStyle(Palette.live).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(job.settings.prompt).font(.caption).lineLimit(1).truncationMode(.tail)
                Text(app.batchSize > 1
                     ? job.legend + " · " + String(localized: "image \(app.batchImage + 1)/\(app.batchSize)")
                     : job.legend)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if app.remaining(at: .now) != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(verbatim: "≈ " + Figures.duration(app.remaining(at: context.date) ?? 0))
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Button { app.cancel() } label: {
                Image(systemName: "stop.circle.fill").foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Stop (⌘.)")
            .accessibilityLabel(Text("Stop"))
        }
        .frame(height: Self.rowHeight)
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Waiting · \(app.file.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Stop All", role: .destructive) { app.stopAll() }
                    .buttonStyle(.chartLink).font(.caption)
                    .help("Clear the queue and stop the current render")
            }
            if app.file.count > Self.visibleRows {
                ScrollView(.vertical) { rows }
                    .frame(height: (CGFloat(Self.visibleRows) + 0.5) * (Self.rowHeight + Self.rowSpacing))
            } else {
                rows
            }
        }
    }

    private static let visibleRows = 4
    private static let rowHeight: CGFloat = 30
    private static let rowSpacing: CGFloat = 6

    private var rows: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(Array(app.file.enumerated()), id: \.element.id) { n, job in
                HStack(spacing: 8) {
                    Text(verbatim: "\(n + 1)").font(.caption2).monospacedDigit().foregroundStyle(.secondary).frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(job.settings.prompt).font(.caption).lineLimit(1).truncationMode(.tail)
                        Text(job.legend).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let e = app.estimation(job) {
                        Text(verbatim: "≈ " + Figures.duration(e)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Button { app.remove(job) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from the queue")
                    .accessibilityLabel(Text("Remove from the queue"))
                }
                .frame(height: Self.rowHeight)
            }
        }
    }
}

/// **A problem, as the user reads it**: the sentence, what to do, and — smaller, selectable — the
/// engine's technical detail when there is one (an issue quotes it).
struct ProblemView: View {
    let problem: Problem
    var close: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(problem.title).fontWeight(.medium)
                if let s = problem.suggestion { Text(s).foregroundStyle(.secondary) }
                if let d = problem.detail {
                    Text(d).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(4)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let close {
                Button(action: close) { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .buttonStyle(.borderless).help("Close")
                    .accessibilityLabel(Text("Close"))
            }
        }
        .font(.callout)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Palette.failure.opacity(0.1)))
    }
}
