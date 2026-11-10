// **The Studio window: full-bleed borderless darkroom chrome, custom Studio Header Bar,
// collapsible Signal-Chain Rack on the left, and the Canvas + Studio Composer on the right.**

import AppKit
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Bindable var app: AppState
    var toggleStatistics: () -> Void = {}
    @State private var showsSidebar = false
    @State private var sidebarWidth: CGFloat = 372

    var body: some View {
        let _ = StudioHub.shared.theme
        VStack(spacing: 0) {
            StudioHeaderBar(
                app: app,
                showsSidebar: $showsSidebar,
                toggleStatistics: toggleStatistics
            )
            Rectangle().fill(Palette.hairline).frame(height: 1)

            HStack(spacing: 0) {
                if showsSidebar {
                    Sidebar(app: app)
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    SidebarResizeHandle(width: $sidebarWidth)
                }
                GraphCanvas(app: app, showsSidebar: showsSidebar)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
        }
        .background(Palette.canvas)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: app.sidebarTab, initial: true) { _, tab in
            withAnimation(Motion.pick(.spring(response: 0.28, dampingFraction: 0.86))) {
                showsSidebar = (tab == .explore)
            }
            if tab == .explore {
                app.showsGallery = false
                if !app.welcomes, !LabModel.shared.detached {
                    LabModel.shared.unfold()
                }
            }
        }
        .sheet(isPresented: $app.managementOpen) { ModelManagement(app: app) }
        .sheet(item: $app.licenseRequest) { request in LicenseSheet(app: app, card: request.card) }
        .sheet(item: $app.hubOffer) { _ in HubSheet(app: app) }
        .sheet(isPresented: $app.diagnosticOpen) { DiagnosticSheet(app: app) }
        .sheet(item: Bindable(StudioHub.shared).subjectDraft) { draft in
            SubjectSheet(lab: LabModel.shared, draft: draft)
        }
        .overlay {
            if app.fullScreen, let image = app.selectedImage?.image { FullScreen(app: app, image: image) }
        }
        .animation(Motion.pick(.easeInOut(duration: 0.15)), value: app.fullScreen)
    }
}

// MARK: - Custom Full-Bleed Studio Header Bar

private struct StudioHeaderBar: View {
    @Bindable var app: AppState
    @Binding var showsSidebar: Bool
    let toggleStatistics: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private enum WorkspaceMode {
        case studio, gallery, series
    }

    private var activeMode: WorkspaceMode {
        if app.showsGallery && !app.history.isEmpty { return .gallery }
        return app.sidebarTab == .explore ? .series : .studio
    }

    var body: some View {
        ZStack {
            WindowDragArea()

            HStack(spacing: 14) {
                // Left: Rack toggle + understated typographic Siliconed wordmark (aligned with 52pt .unified traffic lights)
                HStack(spacing: 12) {
                    HeaderIconButton(
                        symbol: "sidebar.left",
                        active: showsSidebar,
                        helpText: "Show or hide the Signal-Chain Rack"
                    ) {
                        withAnimation(Motion.pick(.spring(response: 0.28, dampingFraction: 0.86))) {
                            showsSidebar.toggle()
                        }
                    }

                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(width: 1, height: 15)

                    HStack(spacing: 8) {
                        Text(verbatim: "Siliconed")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.15)
                            .foregroundStyle(.primary.opacity(0.92))

                        computeBadge
                    }
                    .allowsHitTesting(false)
                }

                Spacer(minLength: 12)

                // Center: Crisp 3-Mode Studio Workspace Switcher
                HStack(spacing: 3) {
                    workspaceSegment(
                        title: "Studio",
                        symbol: "sparkles",
                        active: activeMode == .studio
                    ) {
                        withAnimation(Motion.pick(.spring(response: 0.25, dampingFraction: 0.86))) {
                            app.showsGallery = false
                            app.sidebarTab = .generate
                        }
                    }

                    workspaceSegment(
                        title: "Gallery",
                        symbol: "square.grid.2x2",
                        badge: app.history.isEmpty ? nil : "\(app.history.count)",
                        active: activeMode == .gallery,
                        disabled: app.history.isEmpty && !app.showsGallery
                    ) {
                        withAnimation(Motion.pick(.spring(response: 0.25, dampingFraction: 0.86))) {
                            app.showsExploration = false
                            app.showsGallery = true
                        }
                    }

                    workspaceSegment(
                        title: "Chain & Series",
                        symbol: "point.3.connected.trianglepath.dotted",
                        badge: app.seriesRenders > 1 ? "±\(app.seriesRenders)" : nil,
                        badgeTint: Palette.bracket,
                        active: activeMode == .series
                    ) {
                        withAnimation(Motion.pick(.spring(response: 0.25, dampingFraction: 0.86))) {
                            app.showsGallery = false
                            app.sidebarTab = .explore
                        }
                    }
                }
                .padding(3)
                .background(Capsule().fill(Palette.well))
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))

                Spacer(minLength: 12)

                // Right: Theme Switcher + Prompt Lab + Export/Stats Action Bar
                HStack(spacing: 10) {
                    StudioThemePill()

                    PromptLabHeaderButton()

                    actionCluster
                }
            }
            .padding(.leading, 96)
            .padding(.trailing, 20)
        }
        .frame(height: 52)
        .background(Palette.column)
    }

    @ViewBuilder private var computeBadge: some View {
        if let mirror = app.mirror {
            HStack(spacing: 4) {
                Circle().fill(Palette.sky).frame(width: 5.5, height: 5.5)
                Text(verbatim: mirror.macName.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Palette.hairline))
        } else if app.inProgress {
            HStack(spacing: 4) {
                Circle().fill(Palette.live).frame(width: 5.5, height: 5.5)
                Text("RENDERING")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.live)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.live.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Palette.live.opacity(0.35)))
        }
    }

    private func workspaceSegment(
        title: LocalizedStringKey,
        symbol: String,
        badge: String? = nil,
        badgeTint: Color? = nil,
        active: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? Palette.live : .secondary)
                Text(title)
                    .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? .primary : .secondary)
                if let badge {
                    Text(verbatim: badge)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(badgeTint ?? (active ? Palette.live : .secondary))
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill((badgeTint ?? Palette.live).opacity(0.14)))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background {
                if active {
                    Capsule()
                        .fill(Palette.surfaceElevated)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 2, y: 1)
                }
            }
            .overlay {
                if active {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.36 : 1)
    }

    private var actionCluster: some View {
        let group = app.targets
        return HStack(spacing: 2) {
            HeaderIconButton(
                symbol: "doc.on.doc",
                disabled: group.isEmpty,
                helpText: group.count > 1 ? String(localized: "Copy the selected images (⇧⌘C)")
                                          : String(localized: "Copy the image (PNG, with its metadata)")
            ) {
                app.copyImages(group)
            }

            HeaderIconButton(
                symbol: "square.and.arrow.down",
                disabled: group.isEmpty,
                helpText: group.count > 1 ? String(localized: "Export the selected images to a folder (⇧⌘E)")
                                          : String(localized: "Save the image (⌘S)")
            ) {
                app.export(group)
            }

            ShareLink(items: group.map(app.transferable), preview: { SharePreview($0.name) }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(group.isEmpty ? Color.secondary.opacity(0.32) : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(group.isEmpty)
            .help("Share — AirDrop, Messages, Mail, Photos…")

            Divider().frame(height: 14).padding(.horizontal, 3)

            HeaderIconButton(
                symbol: "gauge.with.dots.needle.33percent",
                helpText: String(localized: "Render statistics (⌥⌘I)"),
                action: toggleStatistics
            )
        }
        .padding(.horizontal, 5)
        .frame(height: 32)
        .background(Capsule().fill(Color.primary.opacity(0.045)))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
    }
}

private struct PromptLabHeaderButton: View {
    @State private var hovering = false

    var body: some View {
        Button {
            LabWindow.shared.openStudio()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(hovering ? .primary : .secondary)
                Text("Prompt Lab")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(hovering ? Palette.surfaceElevated : Color.primary.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open the Prompt Lab (⌥⌘L)")
    }
}

private struct HeaderIconButton: View {
    let symbol: String
    var active = false
    var disabled = false
    let helpText: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.32) : (active ? Palette.live : (hovering ? .primary : .secondary)))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active ? Palette.live.opacity(0.13) : (hovering && !disabled ? Color.primary.opacity(0.08) : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering = $0 }
        .help(Text(verbatim: helpText))
    }
}

private struct SidebarResizeHandle: View {
    @Binding var width: CGFloat
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(width: 1)
            .overlay {
                Color.clear
                    .frame(width: 7)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let base = dragStartWidth ?? width
                                if dragStartWidth == nil { dragStartWidth = width }
                                width = min(520, max(320, base + value.translation.width))
                            }
                            .onEnded { _ in
                                dragStartWidth = nil
                            }
                    )
            }
    }
}

// MARK: - The materials

/// **Reduce Motion** (System Settings ▸ Accessibility ▸ Display): the app's springs and fades are
/// dropped, the state changes at once.
enum Motion {
    static func pick(_ animation: Animation) -> Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation
    }
}

extension View {
    /// The chosen image leaves by a drag while it is fitted; zoomed in, a drag pans it.
    @ViewBuilder func draggableWhenFitted(_ fitted: Bool, _ item: PNGImage?, preview: CGImage) -> some View {
        if fitted, let item {
            draggable(item) { Image(decorative: preview, scale: 1).resizable().scaledToFit().frame(width: 160, height: 160) }
        } else {
            self
        }
    }
}

extension View {
    /// macOS 26's glass.
    func glass<S: Shape>(_ shape: S) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// **Glass with soft edges** — the Prompt Lab's plate over the image: the system's glass, its rim fading over a band
    /// instead of stopping at a line, a vapour more than a pane.
    func vapour(cornerRadius: CGFloat, feather: CGFloat = 14) -> some View {
        background {
            Color.clear
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius + feather, style: .continuous))
                .mask {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .padding(feather)
                        .blur(radius: feather / 2)
                }
                .padding(-feather)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - The canvas

/// **The canvas**: the active stage (`SeriesCanvas`, `MasonryGalleryView`, or `SceneView`), the horizontal Studio filmstrip,
/// and at the foot either the Studio `Composer` (on Studio mode) or the docked `LabView` plate (on Chain & Series mode).
private struct GraphCanvas: View {
    @Bindable var app: AppState
    let showsSidebar: Bool

    var body: some View {
        let lab = LabModel.shared
        let showingGallery = app.showsGallery && !app.history.isEmpty
        let studioMode = app.sidebarTab == .generate
        let showsFloatingActivity = !showsSidebar && app.activityShows

        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    if app.showsExploration, let run = app.explored {
                        SeriesCanvas(app: app, run: run)
                    } else if showingGallery {
                        MasonryGalleryView(app: app)
                    } else {
                        SceneView(app: app)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if !studioMode, lab.unfolded, !lab.isWriting, !lab.detached {
                            lab.fold()
                        }
                    }
                )
            }

            if (!app.history.isEmpty || app.explored != nil) && !showingGallery {
                Banner(app: app)
                    .frame(maxWidth: 1080)
                    .padding(.horizontal, 32)
            }

            if studioMode {
                let showsComposer = !showingGallery && !app.welcomes
                if showsComposer || showsFloatingActivity {
                    VStack(spacing: 12) {
                        if showsFloatingActivity { ActivityCard(app: app) }
                        if showsComposer { Composer(app: app) }
                    }
                    .frame(maxWidth: 1080)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
                    .animation(Motion.pick(.easeInOut(duration: 0.2)), value: showsFloatingActivity)
                }
            } else if !showingGallery, !app.welcomes, !(lab.detached && lab.unfolded) {
                LabView(model: lab)
                    .frame(maxWidth: 1040)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .animation(Motion.pick(.spring(duration: 0.3)), value: lab.unfolded)
            }
        }
        .background { AmbientBackdropView(app: app) }
        .onAppear {
            lab.watchRender()
            lab.refresh()
        }
        .onChange(of: app.welcomes) { _, welcomes in
            if !welcomes, app.sidebarTab == .explore {
                lab.welcomeEnded()
            }
        }
        .overlay(alignment: .top) {
            if let toast = app.toast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .studioCard(cornerRadius: 999)
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Motion.pick(.spring(duration: 0.3)), value: app.toast)
        // Drop destination: a Siliconed PNG restores settings; otherwise routes into edit references, starting image, or Prompt Lab.
        .dropDestination(for: DroppedImage.self) { items, _ in
            var files: [URL] = []
            var pasted: [Data] = []
            for item in items {
                switch item {
                case .file(let url) where !AppState.importable(url): files.append(url)
                case .file: break
                case .png(let data): pasted.append(data)
                }
            }
            if items.count == 1, files.count == 1, app.restoreSettings(fromPNG: files[0]) { return true }
            if app.editingPossible, !(files.isEmpty && pasted.isEmpty) {
                pasted.forEach { app.addReference(png: $0) }
                app.addReferences(files)
                return true
            }
            if app.usedStart != nil {
                if let data = pasted.first, let image = AppState.startImage(png: data, name: String(localized: "dropped image")) {
                    app.carryStart(image)
                    return true
                }
                if let url = files.first {
                    app.replaceStart(with: url)
                    return true
                }
            }
            let valid = items.filter { if case .file(let url) = $0 { !AppState.importable(url) } else { true } }
            guard !valid.isEmpty else { return false }
            for image in valid { lab.load(image) }
            if studioMode { LabWindow.shared.openStudio() } else { lab.unfold() }
            return true
        }
    }
}

// MARK: - Full screen

/// The chosen image over the whole window — Escape, Space or a click closes it; ← → walk along the strip.
private struct FullScreen: View {
    let app: AppState
    let image: CGImage

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
            Image(image, scale: 1, label: Text(verbatim: app.selectedEntry?.settings.prompt ?? ""))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(24)
            Group {
                Button("Close") { app.fullScreen = false }
                    .keyboardShortcut(.cancelAction)
                Button("Previous") { app.chooseAdjacent(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next") { app.chooseAdjacent(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Close") { app.fullScreen = false }
                    .keyboardShortcut(.space, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { app.fullScreen = false }
        .transition(.opacity)
    }
}
