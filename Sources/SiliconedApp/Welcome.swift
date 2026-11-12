// The first launch, the waiting states and the progress indicator: what the canvas shows
// before there is an image. Split from `MainView.swift`.

import AppKit
import Siliconed
import SwiftUI
import UniformTypeIdentifiers

/// **The first launch**: nothing comes with the app, so the canvas says so and offers
/// the models in front side by side (`AppState.frontFamilies`) — what each does, its license, its
/// place on disk. « Install… » opens the Models sheet on that model's license: nothing is downloaded
/// before it is accepted.
struct Welcome: View {
    let app: AppState
    /// The version chosen on each card (`Family.preselectedVariant` until the user picks another:
    /// Standard, Light on a Mac of 8 GB).
    @State private var choice: [Family: Variant] = [:]

    /// **The models an update left without their weights** (`AppState.outdatedVariant`): installed before, they no longer
    /// render until they take the new ones — said as an update, not as a first launch.
    private var outdated: [Family] { AppState.frontFamilies.filter { app.outdatedVariant(of: $0) != nil } }

    var body: some View {
        let families = AppState.frontFamilies
        GeometryReader { geo in
            ScrollView(.vertical) {
                VStack(spacing: 30) {
                    VStack(spacing: 10) {
                        if outdated.isEmpty {
                            Text("Welcome to Siliconed")
                                .font(.system(size: 32, weight: .semibold))
                                .tracking(-0.5)
                            Text("Choose a model to begin. Its license and the space it takes are shown before anything is downloaded.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 520)
                        } else {
                            Text("New Weights for Your Models")
                                .font(.system(size: 32, weight: .semibold))
                                .tracking(-0.5)
                            Text("This version of Siliconed brings new weights for the models marked below: update them to render again. The space they take is shown before anything is downloaded.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 540)
                        }
                    }

                    // Side by side when the canvas holds all five, else 3 + 2, else 2 + 2 + 1 — each row sharing equal card height.
                    GlassEffectContainer(spacing: 18) {
                        ViewThatFits(in: .horizontal) {
                            cardRow(families)
                            VStack(spacing: 18) {
                                cardRow(Array(families.prefix(3)))
                                cardRow(Array(families.dropFirst(3)))
                            }
                            VStack(spacing: 18) {
                                cardRow(Array(families.prefix(2)))
                                cardRow(Array(families.dropFirst(2).prefix(2)))
                                cardRow(Array(families.dropFirst(4)))
                            }
                        }
                    }

                    if let title = app.forgeInProgress {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(title).font(.callout).foregroundStyle(.secondary)
                        }
                    } else {
                        Button("All Models…") { app.managementOpen = true }
                            .buttonStyle(.chartLink)
                            .font(.callout.weight(.medium))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.vertical, 36)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.automatic)
        }
    }

    private func cardRow(_ row: [Family]) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(row, id: \.self) { card($0) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func card(_ family: Family) -> some View {
        let model = ModelCard.of(family)
        let old = app.outdatedVariant(of: family)
        let variant = choice[family] ?? old ?? family.preselectedVariant()
        let size = family.installedSize(variant)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: Self.symbol(family))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.live)
                Spacer(minLength: 6)
                Text(verbatim: model.licenseName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: 6) {
                Text(verbatim: model.name)
                    .font(.system(size: 16, weight: .semibold))
                if family.isBeta { BetaBadge() }
            }
            Text(Self.blurb(family))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let old {
                Label(String(localized: "Your \(VersionChoice.name(old)) takes new weights"), systemImage: "arrow.down.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.live)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            // Standard, Compact or Light, each with its space on disk (`Family.installedSize`): the rack
            // shows another figure, the memory a render needs (`ModelCard.memoryNeed`).
            if family.variants.count > 1 {
                VersionChoice(family: family, variant: Binding(get: { variant }, set: { choice[family] = $0 }))
                    .font(.caption)
            }
            HStack {
                if family.variants.count == 1 {
                    Label("\(Figures.disk(size.dit + size.encoder + size.components)) on disk", systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("The space it takes on disk once installed")
                }
                Spacer()
                Button(old == nil ? "Install…" : "Update…") { app.offerInstall(family, variant: variant) }
                    .buttonStyle(.prominent)
                    .disabled(!app.managementPossible)
            }
            .padding(.top, 2)
        }
        .multilineTextAlignment(.leading)
        .padding(20)
        .frame(width: 262)
        .frame(minHeight: family.variants.count > 1 ? 296 : 204, maxHeight: .infinity, alignment: .topLeading)
        .glass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if old != nil {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.live.opacity(0.75), lineWidth: 1.5)
            }
        }
    }

    static func symbol(_ family: Family) -> String {
        switch family {
        case .qwenImage21: "wand.and.stars"
        case .anima: "paintbrush"
        case .krea2: "camera.aperture"
        case .mossImage: "text.viewfinder"
        default: "sparkles"
        }
    }

    /// **What the model does, in one sentence** — said, not sold. Also the tooltip of its row in the
    /// Models sheet.
    static func blurb(_ family: Family) -> String {
        switch family {
        case .zImage: String(localized: "Fast and photographic. The one to start with.")
        case .qwenImage21: String(localized: "Generates, and edits a photo by instruction: “change her jacket to red”.")
        // Its publisher trained it for illustration and keeps it there: no photorealism, by choice.
        case .anima: String(localized: "Illustration, painting and anime. No photorealism: its publisher’s choice.")
        // The largest DiT of the four (12.8 B), and the slowest render.
        case .krea2: String(localized: "Aesthetic images, from photography to painting. The largest model, and the slowest.")
        // A 9 B language model reads the prompt; the eight steps come from the community's distillation, not the publisher's.
        case .mossImage: String(localized: "Long, detailed prompts, read by a 9 B language model. Eight steps through the community’s distillation.")
        }
    }
}

/// Before the first preview: the frame of the coming image, illuminated with a subtle latent shimmer
/// (respecting Reduce Motion) and the current stage.
struct Waiting: View {
    let stage: Engine.Stage?

    var body: some View {
        LatentShimmerView(stage: stage)
    }
}

/// **The progress of the running render**: the stage, the step, the batch, the remaining time, one segment
/// per DiT evaluation, and "Stop".
struct ProgressIndicator: View {
    let app: AppState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(label).font(.callout).lineLimit(1)
                    Spacer(minLength: 12)
                    if app.remaining(at: .now) != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("\(Figures.duration(app.remaining(at: context.date) ?? 0)) left")
                                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
                if app.stage == .denoising, app.totalSteps > 0, app.totalSteps <= 60 {
                    HStack(spacing: 3) {
                        ForEach(1...app.totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i <= app.currentStep ? Palette.live : Palette.well)
                                .frame(height: 4)
                        }
                    }
                    .accessibilityHidden(true)
                    .animation(Motion.pick(.easeOut(duration: 0.3)), value: app.currentStep)
                } else {
                    ProgressView(value: app.fraction).progressViewStyle(.linear)
                }
            }
            .frame(width: 360)
            // One element: what the render is doing, and how far it is.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(verbatim: Figures.percent(Int(app.fraction * 100))))
            Button(role: .destructive) { app.cancel() } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .imageScale(.large)
            .help("Stop (⌘.)")
            .accessibilityLabel(Text("Stop"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .glass(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var label: String {
        var pieces: [String] = []
        if let t = app.currentJob { pieces.append(t.settings.modelName) }
        if app.batchSize > 1 {
            pieces.append(String(localized: "image \(app.batchImage + 1)/\(app.batchSize)"))
        }
        if app.stage == .denoising, app.totalSteps > 0 {
            pieces.append(String(localized: "step \(app.currentStep)/\(app.totalSteps)"))
        } else {
            pieces.append(app.stage?.label ?? String(localized: "Preparing…"))
        }
        return pieces.joined(separator: " · ")
    }
}
