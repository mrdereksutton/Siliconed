// **The Studio window: native macOS 26 Liquid Glass `NavigationSplitView` & unified toolbar,
// collapsible Signal-Chain Rack on the left, and full-bleed Canvas + floating Liquid Glass Composer on the right.**

import AppKit
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Bindable var app: AppState
    var toggleStatistics: () -> Void = {}
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private enum WorkspaceMode: Hashable {
        case studio, gallery, series
    }

    private var workspaceBinding: Binding<WorkspaceMode> {
        Binding(
            get: {
                if app.showsGallery { return .gallery }
                return app.sidebarTab == .explore ? .series : .studio
            },
            set: { mode in
                withAnimation(Motion.pick(.spring(response: 0.28, dampingFraction: 0.86))) {
                    switch mode {
                    case .studio:
                        app.showsGallery = false
                        app.showsExploration = false
                        app.sidebarTab = .generate
                    case .gallery:
                        app.showsExploration = false
                        app.showsGallery = true
                    case .series:
                        app.showsGallery = false
                        app.sidebarTab = .explore
                    }
                }
            }
        )
    }

    var body: some View {
        let _ = StudioHub.shared.theme
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(app: app)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        } detail: {
            GraphCanvas(app: app, showsSidebar: columnVisibility != .detailOnly)
                .navigationTitle(Text(verbatim: ""))
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(Motion.pick(.spring(response: 0.28, dampingFraction: 0.86))) {
                        if columnVisibility == .detailOnly {
                            app.showsGallery = false
                            app.sidebarTab = .explore
                        } else {
                            app.showsExploration = false
                            app.sidebarTab = .generate
                        }
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .help("Show or hide the Signal-Chain Rack (⌃⌘S)")
            }

            ToolbarItem(placement: .principal) {
                Picker("Workspace", selection: workspaceBinding) {
                    Text("Studio").tag(WorkspaceMode.studio)
                    Text("Gallery").tag(WorkspaceMode.gallery)
                    Text("Series").tag(WorkspaceMode.series)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .help("Switch workspace: Studio, Gallery, or Chain & Series")
            }

            if !app.targets.isEmpty {
                ToolbarItemGroup(placement: .primaryAction) {
                    let group = app.targets
                    Button { app.copyImages(group) } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                    }
                    .help(group.count > 1 ? "Copy the selected images (⇧⌘C)" : "Copy the image (PNG, with its metadata)")

                    Button { app.export(group) } label: {
                        Label("Save…", systemImage: "square.and.arrow.down")
                    }
                    .help(group.count > 1 ? "Export the selected images to a folder (⇧⌘E)" : "Save the image (⌘S)")

                    ShareLink(items: group.map(app.transferable), preview: { SharePreview($0.name) }) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                    .help("Share — AirDrop, Messages, Mail, Photos…")
                }

                ToolbarSpacer(.fixed, placement: .primaryAction)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Studio Theme", selection: Bindable(StudioHub.shared).theme) {
                        ForEach(StudioTheme.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    .pickerStyle(.inline)

                    Divider()

                    Toggle("Ambient Backlight", isOn: Bindable(StudioHub.shared).ambientBacklight)
                } label: {
                    Label("Studio Theme", systemImage: "swatchpalette")
                }
                .menuIndicator(.hidden)
                .help("Switch Studio Theme & Atmosphere")

                Button {
                    LabWindow.shared.openStudio()
                } label: {
                    Label("Prompt Lab", systemImage: "wand.and.sparkles")
                }
                .help("Open the Prompt Lab (⌥⌘L)")

                Button(action: toggleStatistics) {
                    Label("Statistics", systemImage: "gauge.with.dots.needle.33percent")
                }
                .help("Render statistics (⌥⌘I)")
            }
        }
        .onChange(of: app.sidebarTab, initial: true) { _, tab in
            withAnimation(Motion.pick(.spring(response: 0.28, dampingFraction: 0.86))) {
                columnVisibility = (tab == .explore) ? .all : .detailOnly
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
        let showingGallery = app.showsGallery
        let studioMode = app.sidebarTab == .generate
        let showsFloatingActivity = !showsSidebar && app.activityShows
        let hasFilmstrip = (!app.history.isEmpty || app.explored != nil) && !showingGallery
        let showsComposer = studioMode && !showingGallery && !app.welcomes
        let showsDockedLab = !studioMode && !showingGallery && !app.welcomes && !(lab.detached && lab.unfolded)

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
        .simultaneousGesture(
            TapGesture().onEnded {
                if !studioMode, lab.unfolded, !lab.isWriting, !lab.detached {
                    lab.fold()
                }
            }
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasFilmstrip || showsFloatingActivity || showsComposer || showsDockedLab {
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        if hasFilmstrip {
                            Banner(app: app)
                                .frame(maxWidth: 1080)
                        }

                        if studioMode {
                            if showsFloatingActivity {
                                ActivityCard(app: app)
                                    .frame(maxWidth: 1080)
                            }
                            if showsComposer {
                                Composer(app: app)
                                    .frame(maxWidth: 1080)
                            }
                        } else if showsDockedLab {
                            LabView(model: lab)
                                .frame(maxWidth: 1040)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 18)
                .animation(Motion.pick(.easeInOut(duration: 0.2)), value: showsFloatingActivity)
                .animation(Motion.pick(.spring(duration: 0.3)), value: lab.unfolded)
            }
        }
        .background { AmbientBackdropView(app: app) }
        .onAppear {
            lab.watchRender()
            lab.refresh()
        }
        .onChange(of: app.inProgress) { _, running in
            if running, app.followsRender {
                app.showsGallery = false
            }
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
                    .glass(Capsule())
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
