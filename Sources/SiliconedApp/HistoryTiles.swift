// The Studio filmstrip: horizontal history thumbnails, live & series tiles, and context menus.
// Split from `MainView.swift`.

import AppKit
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

// MARK: - The history filmstrip

/// **The history, as a horizontal Studio filmstrip above the Composer**: the newest on the left,
/// the series' tile and the render under way first; at its trailing end, how many images, a shortcut
/// to the Masonry Gallery, and the thumbnails' size.
struct Banner: View {
    @Bindable var app: AppState

    var body: some View {
        let _ = StudioHub.shared.theme
        HStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        if let run = app.explored { ExplorationTile(app: app, run: run) }
                        // A series' cell shows its own preview in the grid: no second tile for it.
                        if let job = app.currentJob, app.explored?.jobs.contains(job.ordinal) != true {
                            LiveTile(app: app, job: job)
                        }
                        ForEach(app.history) { entry in
                            Thumbnail(app: app, entry: entry,
                                      marked: app.isMarked(entry.id) && !(app.inProgress && app.followsRender),
                                      shown: entry.id == app.selectedEntry?.id && app.marked.count > 1)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollIndicators(.never)
                .onChange(of: app.selection) { _, id in
                    if let id { withAnimation(Motion.pick(.default)) { reader.scrollTo(id, anchor: .center) } }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    Divider().frame(height: max(28, app.thumbnailSide * 0.55))
                    sizeControl
                }
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .frame(height: app.thumbnailSide + 18)
    }

    /// At the strip's end: how many images, a shortcut to the masonry gallery, and the thumbnails' size.
    private var sizeControl: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Text(app.history.count == 1 ? String(localized: "1 image") : String(localized: "\(app.history.count) images"))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                if !app.history.isEmpty {
                    Button {
                        withAnimation(Motion.pick(.easeInOut(duration: 0.2))) {
                            app.showsExploration = false
                            app.showsGallery = true
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.live)
                    }
                    .buttonStyle(.borderless)
                    .help("Open masonry gallery")
                    .accessibilityLabel(Text("Gallery"))
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "photo").imageScale(.small)
                Slider(value: $app.thumbnailSide, in: 48...140)
                    .frame(width: 80)
                    .controlSize(.mini)
                    .tint(Palette.control)
                Image(systemName: "photo").imageScale(.large)
            }
            .foregroundStyle(.secondary)
            .help("Thumbnail size")
            .accessibilityLabel(Text("Thumbnail size"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// **A history image in the strip**: a click shows it, ⌘-click and ⇧-click mark several (`AppState.click`),
/// a drag carries its PNG out — to the Finder, a message, another app. Marked, it wears `Palette.live`;
/// among several marked, the one shown wears it thicker.
private struct Thumbnail: View {
    let app: AppState
    let entry: Entry
    let marked: Bool
    let shown: Bool
    @State private var hover = false

    var body: some View {
        let side = app.thumbnailSide
        let l = Double(entry.width), h = Double(entry.height)
        let isFav = StudioHub.shared.isFavorite(entry)
        Image(decorative: entry.vignette, scale: 1)
            .resizable()
            .interpolation(.medium)
            .scaledToFill()
            .frame(width: side * min(1, l / h), height: side * min(1, h / l))
            .overlay(alignment: .topLeading) {
                if isFav {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.65), radius: 2)
                        .padding(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(marked ? Palette.live : hover ? Color.white.opacity(0.45) : Palette.hairline,
                              lineWidth: marked ? (shown ? 3 : 2) : 1))
            .opacity(marked || hover ? 1 : 0.88)
            // **The ✕ of the hovered tile** (issue 16): acts on this image alone; ⌘Z brings it back.
            .overlay(alignment: .topTrailing) {
                if hover {
                    Button { app.delete(entry) } label: {
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain).padding(3)
                    .help("Remove from History (⌘Z brings it back)")
                    .accessibilityLabel(Text("Remove from History"))
                }
            }
            .frame(height: side + 4)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture {
                MainWindow.shared.releaseTextFocus()
                app.showsGallery = false
                app.click(entry.id, modifiers: NSEvent.modifierFlags)
            }
            .draggable(app.transferable(entry)) {
                Image(decorative: entry.vignette, scale: 1).resizable().scaledToFit().frame(width: 96, height: 96)
            }
            .help(Text(verbatim: "\(entry.settings.prompt)\n\(entry.legend)"))
            .contextMenu { MenuEntry(app: app, entry: entry) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: entry.settings.prompt))
            .accessibilityValue(Text(verbatim: entry.legend))
            .accessibilityAddTraits(marked ? [.isButton, .isSelected] : .isButton)
            .animation(Motion.pick(.easeOut(duration: 0.12)), value: hover)
    }
}

/// **The running render, at the head of the strip**: its preview in the shape of the coming image,
/// its progress along the bottom. Chosen, the canvas follows the render again.
private struct LiveTile: View {
    let app: AppState
    let job: Job

    var body: some View {
        let side = app.thumbnailSide
        let l = Double(job.settings.format.width), h = Double(job.settings.format.height)
        let following = app.followsRender
        ZStack(alignment: .bottom) {
            Color.primary.opacity(0.08)
            if let p = app.preview {
                Image(decorative: p, scale: 1).resizable().interpolation(.medium).scaledToFill()
            }
            GeometryReader { g in
                Capsule().fill(Palette.live)
                    .frame(width: max(4, g.size.width * app.fraction), height: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding(3)
        }
        .frame(width: side * min(1, l / h), height: side * min(1, h / l))
        .overlay(alignment: .topTrailing) {
            if app.batchSize > 1 {
                Text(verbatim: "\(app.batchImage + 1)/\(app.batchSize)")
                    .font(.caption2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(following ? Palette.live : Palette.hairline, lineWidth: following ? 2.5 : 1))
        .frame(height: side + 4)
        .contentShape(Rectangle())
        .onTapGesture { app.followsRender = true; app.showsExploration = false; app.showsGallery = false }
        .help("The render in progress")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("The render in progress"))
        .accessibilityValue(Text(verbatim: Figures.percent(Int(app.fraction * 100))))
        .accessibilityAddTraits(.isButton)
    }
}

/// **The series, at the head of the strip**: its grid in small, how far it is; a click brings the
/// grid back to the canvas.
private struct ExplorationTile: View {
    let app: AppState
    let run: GridRun

    var body: some View {
        let side = app.thumbnailSide
        ZStack {
            Color.primary.opacity(0.08)
            Image(systemName: "square.grid.3x3").font(.system(size: side * 0.36)).foregroundStyle(.secondary)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: "\(run.entries.count)/\(run.jobs.count)").font(.caption2).monospacedDigit()
                .padding(4)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(app.showsExploration ? Palette.live : Palette.hairline, lineWidth: app.showsExploration ? 2.5 : 1))
        .frame(height: side + 4)
        .contentShape(Rectangle())
        .onTapGesture { app.showsExploration = true; app.showsGallery = false }
        .help("The series’ grid")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("The series’ grid"))
        .accessibilityValue(Text(verbatim: "\(run.entries.count)/\(run.jobs.count)"))
        .accessibilityAddTraits(.isButton)
    }
}

/// **« Variations »'s two choices** — the bar under the image and the context menu.
struct VariationButtons: View {
    let app: AppState
    let entry: Entry

    var body: some View {
        Button("Subtle Variations") { app.vary(entry, .subtle) }
        Button("Strong Variations") { app.vary(entry, .strong) }
    }
}

/// **« Enlarge ×4 »** in the bar under the image: greyed with its reason when it cannot; while it
/// works, a spinner — or the model's download, in percent.
struct EnlargeButton: View {
    let app: AppState
    let entry: Entry

    var body: some View {
        if app.enlarging == entry.id {
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                if let p = app.enlargeDownload { Text(Figures.percent(Int(p * 100))).font(.caption).monospacedDigit() }
            }
            .help(app.enlargeDownload == nil ? "Enlarging…" : "macOS is downloading the enlargement model")
        } else {
            Button { app.enlarge(entry) } label: { Image(systemName: "arrow.up.left.and.down.right.magnifyingglass") }
                .disabled(app.enlargeRefusal(entry) != nil)
                .help(app.enlargeHelp(entry))
                .accessibilityLabel(Text("Enlarge ×4"))
        }
    }
}

/// **Sending an image to be edited**: by the rack's model when it edits; otherwise by an installed model
/// that does — chosen in the rack on the way.
private struct EditButtons: View {
    let app: AppState
    let entry: Entry

    var body: some View {
        if app.editingPossible {
            Button("Edit with \(app.card?.name ?? "")") { app.placeReference(entry) }
        } else if app.editors.count == 1, let model = app.editors.first {
            Button("Edit with \(model.name)") { app.edit(entry, with: model.id) }
        } else if !app.editors.isEmpty {
            Menu("Edit With") {
                ForEach(app.editors, id: \.id) { model in
                    Button(model.name) { app.edit(entry, with: model.id) }
                }
            }
        }
    }
}

/// An image's context menu (the displayed image like the thumbnails). On one of several marked images,
/// what concerns files acts on all of them, as in the Finder.
struct MenuEntry: View {
    let app: AppState
    let entry: Entry

    var body: some View {
        let group = app.marked.count > 1 && app.marked.contains(entry.id) ? app.targets : [entry]
        if group.count > 1 {
            Button("Export \(group.count) Images…") { app.export(group) }
            Button("Copy \(group.count) Images") { app.copyImages(group) }
            ShareLink("Share…", items: group.map(app.transferable), preview: { SharePreview($0.name) })
            Divider()
            Button("Remove \(group.count) Images from History", role: .destructive) { app.delete(group) }
        } else {
            let fav = StudioHub.shared.isFavorite(entry)
            Button(fav ? "Unfavorite" : "Favorite") { StudioHub.shared.toggleFavorite(entry) }
            Button("Save…") { app.save(entry) }
            Button("Copy Image") { app.copyImage(entry) }
            ShareLink("Share…", item: app.transferable(entry), preview: SharePreview(app.exportName(entry)))
            Button("Full Screen") { app.show(entry.id); app.fullScreen = true }
            Divider()
            Button(app.busy ? "Render Again (Same Seed), Queued" : "Render Again (Same Seed)") { app.redo(entry) }
            if entry.grid == nil {
                Menu("Variations") { VariationButtons(app: app, entry: entry) }
                    .disabled(!app.canVary(entry))
            }
            if entry.grid == nil {
                Button("Enlarge ×4") { app.enlarge(entry) }
                    .disabled(app.enlargeRefusal(entry) != nil)
            }
            if entry.grid == nil {
                Button("Crop…") { app.beginCrop(entry) }
                    .disabled(app.cropRefusal(entry) != nil)
            }
            Button(entry.grid == nil ? "Reuse These Settings" : "Reuse This Grid") { app.restoreSettings(entry) }
            if entry.grid == nil { EditButtons(app: app, entry: entry) }
            if entry.grid == nil {
                Button("Save as @Subject…") {
                    StudioHub.shared.beginNamingSubject(from: .png(entry.png), app: app)
                }
            }
            if entry.grid == nil {
                Button("Send to the Prompt Lab") {
                    LabModel.shared.send(entry)
                    if app.sidebarTab == .generate {
                        LabWindow.shared.openStudio()
                    }
                }
            }
            Divider()
            Button("Remove from History", role: .destructive) { app.delete(entry) }
        }
    }
}
