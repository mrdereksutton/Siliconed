// Fork: **the left column's Generate tab** — what the composer leaves out, as a settings form rather
// than a chain of boxes: an edit's images (on a model that edits), the LoRA stack with each strength
// under the hand, then the seed, the steps, the detail, the solver and the step previews.

import AppKit
import Siliconed
import SwiftUI

struct GenerateSettings: View {
    @Bindable var app: AppState

    var body: some View {
        Form {
            if app.editingPossible {
                Section { ImagesNode(app: app) }
            }
            if app.missing == nil, app.card != nil {
                Section {
                    if app.loras.isEmpty {
                        Text(app.compatibleLoras.isEmpty ? "No LoRA for this model" : "Add a LoRA to the stack (3 at most)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach($app.loras) { $slot in LoRARow(app: app, slot: $slot) }
                } header: {
                    HStack(spacing: 8) {
                        Text("LoRA")
                        if !app.loras.isEmpty {
                            Text(verbatim: "\(app.loras.count)/\(AppState.maxLoRA)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if !app.compatibleLoras.isEmpty { LoRAAddMenu(app: app) }
                        Button("Import…") { app.chooseToImport() }
                            .buttonStyle(.link)
                            .disabled(!app.importPossible)
                            .help("A model (.safetensors or .gguf) or a LoRA (.safetensors), as published on Civitai")
                    }
                }
                Section {
                    seed
                    if !app.variations.isEmpty { variation }
                    LabeledContent("Steps") {
                        Stepper(value: $app.steps, in: 1...50) { Text(verbatim: "\(app.steps)").monospacedDigit() }
                            .fixedSize()
                    }
                    .help(String(localized: "\(app.card?.defaultSteps ?? 8) steps: the count this Turbo model is distilled for"))
                    // Not on a model that offers none (Anima): a choice that changes nothing is not shown.
                    if app.offersDetail {
                        LabeledContent("Detail") {
                            Picker("Detail", selection: $app.detail) {
                                ForEach(Detail.allCases, id: \.self) { Text(verbatim: $0.choice).tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden().fixedSize()
                        }
                        .help("Adds fine texture and small details; Most can over-sharpen")
                    }
                    // More Solvers (Settings › Advanced): how a step moves to the next. Euler is the distillation's own.
                    if app.offeredSolvers.count > 1 {
                        LabeledContent("Solver") {
                            Picker("Solver", selection: $app.solver) {
                                ForEach(app.offeredSolvers, id: \.self) { Text(verbatim: $0.choice).tag($0) }
                            }
                            .labelsHidden().fixedSize()
                        }
                        .help("How each step moves to the next, with the same steps: Euler is the one this model was distilled for")
                    }
                    Toggle("Preview every step", isOn: $app.previews)
                        .help("Shows the image taking shape on the canvas after each step. It does not change the image.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var seed: some View {
        LabeledContent("Seed") {
            HStack(spacing: 8) {
                if app.fixedSeed {
                    TextField("Seed", value: $app.seed, format: .number.grouping(.never))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Button { app.seed = UInt64.random(in: 0...UInt64(UInt32.max)) } label: { Image(systemName: "dice") }
                        .buttonStyle(.borderless)
                        .help("Draw a seed")
                        .accessibilityLabel(Text("Draw a seed"))
                }
                Picker("Seed", selection: $app.fixedSeed) {
                    Text("Random").tag(false)
                    Text("Fixed").tag(true)
                }
                .labelsHidden().fixedSize()
            }
        }
        .help("Random: a new seed for every render. Fixed: the same image again")
    }

    private var variation: some View {
        LabeledContent("Variation") {
            HStack(spacing: 6) {
                Text(verbatim: app.variations.map { VariationWords.label($0.strength) }.joined(separator: " + "))
                Button { app.variations = [] } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .help("Remove the variation: the seed’s own image")
                    .accessibilityLabel(Text("Remove the variation: the seed’s own image"))
            }
        }
        .help("The next render is a variation of the seed’s image, like the image it came from")
    }
}
