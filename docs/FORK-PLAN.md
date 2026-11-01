# Siliconed development plan

This fork focuses on the everyday image-generation workflow on a Mac. The first development target is an M4 Mac mini with 16 GB of memory, using the existing Siliconed rendering engine.

## Intended experience

Open the app, choose a model and LoRAs, set the image framing, generate an image, and find that image again after restarting the app. Selecting a saved image should restore its generation settings.

### Generation workspace

- Keep the prompt, model, LoRAs, framing, and generation controls prominent.
- Move the read-only encoder and VAE cards, latent information, and connector legend into an expandable technical view.
- Keep the existing pipeline available for inspecting stages and timings.

### LoRAs and framing

- Expose the existing stack of up to three compatible LoRAs clearly.
- Add editable numeric strengths alongside sliders, with an enable/disable control per slot.
- Show aspect ratios and orientation names beside exact dimensions. Preserve the actual proportions of existing presets; approximate familiar ratios must be marked as approximate.
- Keep custom dimensions and the engine's existing format and memory checks.

### Settings and exploration

- Move the Neural Engine toggle to an explained performance setting. Preserve its per-model choices and record the effective choice with saved images.
- Put Explore inside the main window as a tab alongside Create and Library.
- Explain the comparison grid, sketch dimensions, and completion behavior in the interface. Show the number of renders and use measured time estimates when available.

### Persistent image library

- Save completed generations automatically by default, including the image and its generation metadata.
- Provide an optional session-only mode in Settings.
- Browse saved images using thumbnails and metadata loaded as needed, rather than keeping every full-resolution image in memory.
- Restore the prompt, seed, model, LoRA choices and strengths, dimensions, steps, solver, and applicable performance settings from a saved image.
- Support a user-selected library folder and clear reporting of save failures.

## Development arrangement

Codex owns the generation interface, navigation, application-state integration, and final validation. Claude's independent workstream is the persistence layer and a self-contained gallery component. Each workstream uses a separate checkout or branch, with an agreed metadata and storage interface before integration.

Keep changes to the rendering engine small and directly justified. Preserve model compatibility, memory budgeting, sampling behavior, and existing output metadata while changing the interface. The development app should use a distinct identity and its own application data so it can be tested alongside the installed release.

The full local revision can later be offered upstream as independently reviewable changes. Public contact with the original developer is a separate step from building this fork.

## Completion checks

1. The development app builds and opens with its own preferences and image history.
2. All generation controls work with keyboard and pointer input, and the window remains usable when resized.
3. A completed image is available after restarting the app, with its settings restored correctly.
4. Session-only mode works, and library browsing loads full-resolution images only as needed.
5. A representative render completes on the target Mac with the selected settings and the existing memory checks.

## Current status

The GitHub fork and local development branch are created. This document records the agreed scope. The interface and library changes are not implemented yet. The installed release is Siliconed 0.17; the fork starts from upstream commit `4667d200acb80211b7e51b28ad854a8452127625`.

The baseline app compiles successfully with Swift 6.4, the installed macOS 26.5 SDK, and SwiftPM's native build backend. The rendering-engine target also builds. The local macOS 27 SDK fails to provide the SwiftUI macro component needed by this Command Line Tools installation; using the 26.5 SDK resolves that compile failure without source changes.

The standard app-packaging script also calls `xcstringstool`, which is not present in the installed Command Line Tools. Packaging the separate development app remains a setup task. The verified compile command and remaining setup work are in [LOCAL-BUILD.md](LOCAL-BUILD.md).
