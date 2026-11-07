// **The app's window: the rack on the left, the image on the right**.
//
// On the left (`Sidebar.swift`), **the rack** (`Rack.swift`): the chain of the render drawn from
// `model.chain`, top to bottom in the direction of the signal — the prompt typed in its box, an edit's
// images, the encoders, the DiT with its model, size, seed, steps and LoRAs, the VAE —, wired by
// type, lit stage by stage while it runs; under it, what it will cost and « Generate ». On the
// right, the canvas: the step-by-step preview in the frame of the coming image, then the image, its
// details (the time and memory of each stage), and the history as a strip — in memory, gone with the
// app. The column follows the window: narrower, its boxes narrow and their rows wrap; too narrow,
// the split view folds it away. The sheets: the models (`ModelsSheet.swift`), a license to accept
// (`LicenseSheet.swift`), the diagnostic (`DiagnosticSheet.swift`).

import AppKit
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Bindable var app: AppState
    var toggleStatistics: () -> Void = {}
    /// Fork: the left column folded away on the Generate tab (the composer has it all), shown on Explore.
    @State private var columns: NavigationSplitViewVisibility = .detailOnly

    private static func columns(_ tab: SidebarTab) -> NavigationSplitViewVisibility {
        tab == .explore ? .all : .detailOnly
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar(app: app)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        } detail: {
            GraphCanvas(app: app)
        }
        .onChange(of: app.sidebarTab, initial: true) { _, tab in
            app.composerPanel = nil
            withAnimation(Motion.pick(.easeInOut(duration: 0.25))) { columns = Self.columns(tab) }
            guard tab == .explore else { return }
            if app.explorePrompt.isEmpty { app.explorePrompt = app.prompt }
            app.gridDefaults()
        }
        // Fork: one place per setting — the column is Explore's form and nothing else: on Generate the
        // composer has every setting, so the column never opens there (nor folds away on Explore).
        .onChange(of: columns) { _, shown in
            let wanted = Self.columns(app.sidebarTab)
            if shown != wanted { columns = wanted }
        }
        // Fork: **the top bar on the canvas** — no band of its own, no system title: the name on the
        // left (`Wordmark`), the window's two modes in the middle, the statistics on the right. What
        // acts on an image (copy, save, share) is under the image, with its other actions (`SceneView`).
        .toolbar(removing: .sidebarToggle)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            // The name: beside the traffic lights on Generate; on Explore, at the head of the canvas
            // (a split view's bar puts its items over the detail column).
            ToolbarItem(placement: .navigation) { Wordmark(note: app.wordmarkNote) }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .principal) {
                ModeSwitch(app: app).fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleStatistics) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                }
                .buttonStyle(SiliconIconStyle())
                .help("Render statistics (⌥⌘I)")
                .accessibilityLabel(Text("Statistics"))
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $app.managementOpen) { ModelManagement(app: app) }
        .sheet(item: $app.licenseRequest) { request in LicenseSheet(app: app, card: request.card) }
        .sheet(item: $app.hubOffer) { _ in HubSheet(app: app) }
        .sheet(isPresented: $app.diagnosticOpen) { DiagnosticSheet(app: app) }
        .overlay {
            if app.fullScreen, let image = app.selectedImage?.image { FullScreen(app: app, image: image) }
        }
        .animation(Motion.pick(.easeInOut(duration: 0.15)), value: app.fullScreen)
    }
}

extension AppState {
    /// Fork: beside the name in the top bar — the Mac that computes, or this instance's name (the
    /// subtitle the bar no longer draws).
    var wordmarkNote: String? {
        mirror.map { String(localized: "Computing on “\($0.macName)”") } ?? MainWindow.instanceName
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
}


// MARK: - The canvas

private struct GraphCanvas: View {
    @Bindable var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            if app.showsExploration, let run = app.explored {
                ExplorationCanvas(app: app, run: run)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SceneView(app: app)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if !app.history.isEmpty || app.explored != nil {
                // Fork: the strip in the composer's column, its thumbnails over the prompt; dimmed while a
                // composer panel is open over it.
                Banner(app: app)
                    .frame(maxWidth: 920)
                    .padding(.horizontal, 24)
                    .opacity(app.composerPanel == nil ? 1 : 0.25)
                    .allowsHitTesting(app.composerPanel == nil)
                    .animation(Motion.pick(.easeOut(duration: 0.14)), value: app.composerPanel == nil)
            }
            // Fork: at the foot of the canvas, what goes on (`ActivityCard`) over the prompt and every
            // setting of a render (`Composer`); the Explore tab keeps its own form in the left column.
            if app.activityShows || app.sidebarTab == .generate {
                VStack(spacing: 10) {
                    if app.activityShows {
                        ActivityCard(app: app)
                            .opacity(app.composerPanel == nil ? 1 : 0.25)
                            .allowsHitTesting(app.composerPanel == nil)
                            .animation(Motion.pick(.easeOut(duration: 0.14)), value: app.composerPanel == nil)
                    }
                    if app.sidebarTab == .generate {
                        Composer(app: app)
                            .zIndex(2)
                    }
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .zIndex(2)
                .animation(Motion.pick(.easeInOut(duration: 0.2)), value: app.activityShows)
            }
        }
        // Fork: graphite over a wafer's die grid (`WaferBackground`) — still neutral: the image alone
        // carries the color. It runs under the top bar, which has no band of its own.
        .background(WaferBackground().ignoresSafeArea())
        .overlay(alignment: .top) {
            if let toast = app.toast {
                Text(toast)
                    .font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .siliconPanel(Capsule(), sheen: true)
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Motion.pick(.spring(duration: 0.3)), value: app.toast)
        // A PNG Siliconed wrote brings back its settings — the canvas is where an image is opened.
        // Any other image keeps the canvas's meaning: an edit's reference when the model edits
        // (to edit a Siliconed image, drop it on the composer's « Images », or « Edit This Image »),
        // or the starting image's replacement when a starting image is held.
        .dropDestination(for: URL.self) { urls, _ in
            let images = urls.filter { !AppState.importable($0) }
            if images.count == 1, app.restoreSettings(fromPNG: images[0]) { return true }
            if app.editingPossible, !images.isEmpty {
                app.addReferences(images)
                return true
            }
            if app.usedStart != nil, let first = images.first {
                app.replaceStart(with: first)
                return true
            }
            if images.count == 1, images[0].pathExtension.lowercased() == "png" {
                app.flash(String(localized: "No Siliconed settings in this image"))
            }
            return false
        }
    }
}

// MARK: - Full screen

/// The chosen image over the whole window — the app's viewer, instead of a temporary file
/// opened in Preview (which would have kept it in its recent items). Escape, Space or a
/// click closes it; ← → walk along the strip.
private struct FullScreen: View {
    let app: AppState
    let image: CGImage

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
            Image(image, scale: 1, label: Text(verbatim: app.selectedEntry?.settings.prompt ?? ""))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(24)
            // The keys, invisible: the image is what VoiceOver reads (Esc and a click close it).
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
