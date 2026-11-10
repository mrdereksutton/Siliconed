// Persistent saved-folder indexing, Masonry Gallery mode, and Interactive Starter Canvas.

import AppKit
import ImageIO
import Siliconed
import SwiftUI

// MARK: - Persistent Library Indexing (Downloads › Siliconed)

extension AppState {
    nonisolated private static let maxIndexedSavedImages = 180

    /// Indexes Siliconed PNGs already saved in `EveryImage.shared.folder` (when Incognito is off)
    /// off the main thread so past renders, prompts, seeds and LoRAs appear immediately on launch.
    func loadSavedGalleryIfNeeded() {
        guard mirror == nil, let folder = EveryImage.shared.folder else { return }
        let knownCards = cards
        let currentLibrary = library
        let existingFingerprints = Set(history.map {
            StudioHub.fingerprint(seed: $0.seed, width: $0.width, height: $0.height, prompt: $0.settings.prompt)
        })

        Task.detached(priority: .utility) { [weak self] in
            let fm = FileManager.default
            guard let urls = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            let pngs = urls
                .filter { $0.pathExtension.lowercased() == "png" }
                .compactMap { url -> (URL, Date)? in
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                    guard values?.isRegularFile == true else { return nil }
                    return (url, values?.contentModificationDate ?? .distantPast)
                }
                .sorted { $0.1 > $1.1 }
                .prefix(Self.maxIndexedSavedImages)

            struct LoadedItem: @unchecked Sendable {
                let png: Data
                let vignette: CGImage
                let width: Int
                let height: Int
                let seed: UInt64
                let settings: RenderSettings
                let metadata: [String: String]
                let fingerprint: String
            }

            var loaded: [LoadedItem] = []
            var seen = existingFingerprints

            for (url, _) in pngs {
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
                let meta = PNG.text(data)
                guard let recipe = Engine.Render.Recipe(metadata: meta) else { continue }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let w = (props[kCGImagePropertyPixelWidth] as? Int) ?? recipe.width,
                      let h = (props[kCGImagePropertyPixelHeight] as? Int) ?? recipe.height,
                      w > 0, h > 0 else { continue }

                let promptText = recipe.prompt ?? ""
                let seedVal = recipe.seed ?? 0
                let fp = StudioHub.fingerprint(seed: seedVal, width: w, height: h, prompt: promptText)
                guard !seen.contains(fp) else { continue }
                seen.insert(fp)

                let thumbOpts: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 360,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                ]
                guard let vignette = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else { continue }

                let matchedCard = knownCards.first { !$0.isImported && $0.family.rawValue == recipe.model }
                    ?? knownCards.first { $0.family.rawValue == recipe.model }
                let modelId = matchedCard?.id ?? (recipe.model ?? ModelCard.zImage.id)
                let modelName = matchedCard?.name ?? (recipe.model ?? "Siliconed")
                let slots: [LoRASlot] = recipe.loras.map { entry in
                    let resolved = currentLibrary.lora(entry.path, for: modelId)?.path ?? entry.path
                    return LoRASlot(path: resolved, strength: entry.strength)
                }
                var settings = RenderSettings(
                    identifier: modelId,
                    modelName: modelName,
                    prompt: promptText,
                    format: RecommendedFormat(w, h),
                    steps: recipe.steps ?? matchedCard?.defaultSteps ?? 8,
                    loras: slots,
                    variations: recipe.variations,
                    detail: recipe.detail,
                    solver: recipe.solver,
                    fasterRendering: recipe.fasterRendering,
                    strength: recipe.strength
                )
                if recipe.neuralEngine {
                    settings.offer = AcceleratorOffer(neuralEngine: true)
                }

                loaded.append(LoadedItem(
                    png: data,
                    vignette: vignette,
                    width: w,
                    height: h,
                    seed: seedVal,
                    settings: settings,
                    metadata: meta,
                    fingerprint: fp
                ))
            }

            guard !loaded.isEmpty else { return }
            let snapshot = loaded
            await MainActor.run {
                guard let self, EveryImage.shared.folder == folder else { return }
                let currentFPs = Set(self.history.map {
                    StudioHub.fingerprint(seed: $0.seed, width: $0.width, height: $0.height, prompt: $0.settings.prompt)
                })
                var added: [Entry] = []
                for item in snapshot where !currentFPs.contains(item.fingerprint) {
                    self.lastImage += 1
                    let entry = Entry(
                        ordinal: self.lastImage,
                        job: 0,
                        png: item.png,
                        vignette: item.vignette,
                        width: item.width,
                        height: item.height,
                        seed: item.seed,
                        timings: Engine.Timings(),
                        footprints: Engine.Footprints(),
                        evaluations: item.settings.steps,
                        settings: item.settings,
                        metadata: item.metadata
                    )
                    self.saved.insert(entry.id)
                    added.append(entry)
                }
                guard !added.isEmpty else { return }
                let wasEmpty = self.history.isEmpty
                self.history.append(contentsOf: added)
                if wasEmpty, self.selection == nil, let first = self.history.first {
                    self.selection = first.id
                    self.anchor = first.id
                    if added.count > 1 {
                        self.showsGallery = true
                    }
                }
            }
        }
    }
}

// MARK: - Masonry Gallery View

struct MasonryGalleryView: View {
    @Bindable var app: AppState
    private var hub: StudioHub { .shared }
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var modelFilter: String?
    @State private var targetColumnWidth: Double = 240

    private var modelNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for e in app.history {
            let m = e.settings.modelName
            if !m.isEmpty, seen.insert(m).inserted {
                result.append(m)
            }
        }
        return result
    }

    private var filteredEntries: [Entry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return app.history.filter { entry in
            if favoritesOnly && !hub.isFavorite(entry) { return false }
            if let modelFilter, entry.settings.modelName != modelFilter { return false }
            if !q.isEmpty {
                let inPrompt = entry.settings.prompt.localizedCaseInsensitiveContains(q)
                let inSeed = String(entry.seed).contains(q)
                let inModel = entry.settings.modelName.localizedCaseInsensitiveContains(q)
                let inLora = entry.settings.loras.contains { $0.path.localizedCaseInsensitiveContains(q) }
                if !(inPrompt || inSeed || inModel || inLora) { return false }
            }
            return true
        }
    }

    var body: some View {
        let entries = filteredEntries
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar(count: entries.count)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: favoritesOnly ? "star.slash" : "photo.on.rectangle.angled")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(favoritesOnly ? "No favorite images yet" : "No matching images")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                        if favoritesOnly || modelFilter != nil || !searchText.isEmpty {
                            Button("Show All") {
                                favoritesOnly = false
                                modelFilter = nil
                                searchText = ""
                            }
                            .buttonStyle(.link)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical) {
                        MasonryColumnsLayout(minColumnWidth: CGFloat(targetColumnWidth), spacing: 12) {
                            ForEach(entries) { entry in
                                MasonryCard(
                                    app: app,
                                    entry: entry,
                                    isFavorite: hub.isFavorite(entry),
                                    isMarked: app.isMarked(entry.id)
                                )
                                .aspectRatio(
                                    CGFloat(max(1, entry.width)) / CGFloat(max(1, entry.height)),
                                    contentMode: .fit
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, app.marked.count > 1 ? 80 : 20)
                    }
                }
            }

            if app.marked.count > 1, let entry = app.selectedEntry {
                ImageActions(app: app, entry: entry)
                    .padding(.bottom, 14)
            }
        }
    }

    private func headerBar(count: Int) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                TextField("Search prompts, seeds or LoRAs…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(minWidth: 160, maxWidth: 240)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.hairline))

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    filterChip(title: String(localized: "All"), icon: nil, active: !favoritesOnly && modelFilter == nil) {
                        favoritesOnly = false
                        modelFilter = nil
                    }
                    filterChip(title: String(localized: "Favorites"), icon: "star.fill", active: favoritesOnly) {
                        favoritesOnly.toggle()
                    }
                    ForEach(modelNames, id: \.self) { name in
                        filterChip(title: name, icon: nil, active: modelFilter == name) {
                            modelFilter = (modelFilter == name) ? nil : name
                        }
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 8)

            Text(count == 1 ? String(localized: "1 image") : String(localized: "\(count) images"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3").imageScale(.small)
                Slider(value: $targetColumnWidth, in: 160...380)
                    .frame(width: 76)
                    .controlSize(.mini)
                Image(systemName: "square.grid.2x2").imageScale(.small)
            }
            .foregroundStyle(.secondary)
            .help("Cell size — or pinch, ⌘+ and ⌘−")

            Button {
                withAnimation(Motion.pick(.easeInOut(duration: 0.2))) {
                    app.showsGallery = false
                }
            } label: {
                Label("Stage", systemImage: "rectangle.center.inset.filled")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glass(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func filterChip(title: String, icon: String?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(active ? .yellow : .secondary)
                }
                Text(verbatim: title)
                    .font(.caption.weight(active ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(active ? Color.primary.opacity(0.16) : Color.primary.opacity(0.05)))
            .overlay(Capsule().strokeBorder(active ? Color.primary.opacity(0.45) : Palette.hairline))
        }
        .buttonStyle(.plain)
    }
}

private struct MasonryCard: View {
    let app: AppState
    let entry: Entry
    let isFavorite: Bool
    let isMarked: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Image(decorative: entry.vignette, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFill()

            if hovering || isFavorite || isMarked {
                VStack {
                    HStack {
                        if isMarked {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .font(.system(size: 16))
                        }
                        Spacer()
                        Button {
                            StudioHub.shared.toggleFavorite(entry)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isFavorite ? .yellow : .white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.black.opacity(0.48)))
                        }
                        .buttonStyle(.plain)
                        .help(isFavorite ? "Unfavorite" : "Favorite")
                    }
                    .padding(8)

                    Spacer()

                    if hovering {
                        VStack(alignment: .leading, spacing: 5) {
                            if !entry.settings.prompt.isEmpty {
                                Text(verbatim: entry.settings.prompt)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            HStack(spacing: 6) {
                                Text(verbatim: "\(entry.settings.modelName) · \(entry.width)×\(entry.height)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.78))
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    app.restoreSettings(entry)
                                    app.flash(String(localized: "Settings restored"))
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(.white.opacity(0.18)))
                                }
                                .buttonStyle(.plain)
                                .help("Reuse These Settings")

                                Button {
                                    app.copyImage(entry)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(.white.opacity(0.18)))
                                }
                                .buttonStyle(.plain)
                                .help("Copy Image")
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isMarked ? Color.accentColor : hovering ? Color.white.opacity(0.45) : Palette.hairline,
                    lineWidth: isMarked ? 2.5 : 1
                )
        )
        .shadow(color: .black.opacity(hovering ? 0.34 : 0.18), radius: hovering ? 12 : 6, y: 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) || flags.contains(.shift) {
                app.click(entry.id, modifiers: flags)
            } else {
                app.click(entry.id, modifiers: [])
                withAnimation(Motion.pick(.easeInOut(duration: 0.2))) {
                    app.showsGallery = false
                }
            }
        }
        .draggable(app.transferable(entry)) {
            Image(decorative: entry.vignette, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
        }
        .contextMenu { MenuEntry(app: app, entry: entry) }
    }
}

/// Shortest-column Masonry Waterfall layout preserving every image's true aspect ratio.
struct MasonryColumnsLayout: Layout {
    var minColumnWidth: CGFloat = 240
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let totalWidth = max(minColumnWidth, proposal.width ?? 800)
        let cols = max(1, Int((totalWidth + spacing) / (minColumnWidth + spacing)))
        let colWidth = (totalWidth - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        var heights = Array(repeating: CGFloat(0), count: cols)

        for subview in subviews {
            let col = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            heights[col] += size.height + spacing
        }
        let maxH = max(0, (heights.max() ?? 0) - (subviews.isEmpty ? 0 : spacing))
        return CGSize(width: totalWidth, height: maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let totalWidth = max(1, bounds.width)
        let cols = max(1, Int((totalWidth + spacing) / (minColumnWidth + spacing)))
        let colWidth = (totalWidth - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        var heights = Array(repeating: CGFloat(0), count: cols)

        for subview in subviews {
            let col = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            let x = bounds.minX + CGFloat(col) * (colWidth + spacing)
            let y = bounds.minY + heights[col]
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: colWidth, height: size.height)
            )
            heights[col] += size.height + spacing
        }
    }
}

// MARK: - Interactive Starter Stage (Empty Canvas)

struct InteractiveEmptyStage: View {
    @Bindable var app: AppState

    private struct StarterIdea: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let prompt: String
        let ratio: SizeRatio
        let styleId: String
        let symbol: String
        let colors: [Int]
    }

    private let ideas: [StarterIdea] = [
        StarterIdea(
            id: "street-coupe",
            title: "Midnight Warehouse Coupe",
            prompt: "White JDM sports coupe parked inside an industrial concrete warehouse at dusk, glowing crimson taillights reflecting on damp concrete, volumetric shaft of twilight through high factory windows",
            ratio: SizeRatio(16, 9),
            styleId: "film35",
            symbol: "car.rear.and.tire.marks",
            colors: [0x9E2A2B, 0x1D2D44]
        ),
        StarterIdea(
            id: "studio-musician",
            title: "Editorial Portrait",
            prompt: "Candid medium-format portrait of an indie guitarist holding an offset electric guitar in a sunlit loft studio, natural window key light, subtle dust motes in warm air",
            ratio: SizeRatio(3, 4),
            styleId: "editorial",
            symbol: "guitars",
            colors: [0xB07D52, 0x2B2118]
        ),
        StarterIdea(
            id: "neon-rain",
            title: "Rain-Slicked Alley",
            prompt: "Quiet Tokyo side street after midnight rain, glowing paper lanterns and cyan neon signage mirrored in puddles, steam rising from a tiny ramen stall, cinematic depth",
            ratio: SizeRatio(16, 9),
            styleId: "neon",
            symbol: "sparkles.tv",
            colors: [0x1F7A8C, 0x4A1942]
        ),
        StarterIdea(
            id: "anime-observatory",
            title: "Skyline Observatory",
            prompt: "Cliffside astronomical observatory above a sea of golden sunset clouds, warm brass telescopes catching twilight, swallows in flight, sweeping sense of wonder",
            ratio: SizeRatio(3, 2),
            styleId: "anime",
            symbol: "moon.stars",
            colors: [0x5A67D8, 0xD53F8C]
        ),
        StarterIdea(
            id: "watch-macro",
            title: "Mechanical Chronograph",
            prompt: "Extreme close-up of an open-worked mechanical watch movement, blued steel screws, brushed titanium bridges, ruby jewels catching soft studio rim lighting",
            ratio: SizeRatio(1, 1),
            styleId: "macro",
            symbol: "dial.medium",
            colors: [0x2D6A4F, 0x1B263B]
        ),
        StarterIdea(
            id: "coastal-impasto",
            title: "Stormy Coastline Oil",
            prompt: "Dramatic Atlantic sea cliffs under breaking storm clouds, turquoise surf crashing into white foam, solitary lighthouse beam cutting through mist",
            ratio: SizeRatio(4, 3),
            styleId: "impasto",
            symbol: "paintbrush.pointed",
            colors: [0xC86D51, 0x264653]
        ),
    ]

    private let gridColumns = [
        GridItem(.fixed(210), spacing: 12),
        GridItem(.fixed(210), spacing: 12),
        GridItem(.fixed(210), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("What do you want to see?")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(app.editingPossible
                     ? "Describe an image, pick a starter below, or drop a photo here to edit it."
                     : "Describe an image below or click a starter scene to load its prompt, ratio and style.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(ideas) { idea in
                    StarterCardButton(ideaTitle: idea.title, ratio: idea.ratio, symbol: idea.colors.isEmpty ? "sparkles" : idea.symbol, colors: idea.colors) {
                        withAnimation(Motion.pick(.easeOut(duration: 0.18))) {
                            app.prompt = idea.prompt
                            app.selectScale(idea.ratio, .oneK)
                            StudioHub.shared.selectedStyleId = idea.styleId
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

private struct StarterCardButton: View {
    let ideaTitle: LocalizedStringKey
    let ratio: SizeRatio
    let symbol: String
    let colors: [Int]
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: colors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 68)
                        .overlay(alignment: .bottomLeading) {
                            Image(systemName: symbol)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(10)
                        }

                    Text(verbatim: ratio.description)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.35)))
                        .padding(7)
                }

                HStack(spacing: 4) {
                    Text(ideaTitle)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.left")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .opacity(hovering ? 1 : 0.4)
                }
                .padding(.horizontal, 2)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.09 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hovering ? Color.primary.opacity(0.28) : Palette.hairline)
            )
            .scaleEffect(hovering ? 1.015 : 1.0)
            .animation(Motion.pick(.easeOut(duration: 0.14)), value: hovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
