# Development instructions for this fork

Read `docs/FORK-PLAN.md` before making changes. It records the intended defaults and acceptance checks.

- Use SwiftUI and AppKit conventions already present in the app. Keep the generation form focused on editable controls and put technical information in an optional detail view.
- Persist completed images by default. Session-only behavior is an optional setting. Keep model files separate from generated-image storage.
- Preserve the rendering engine's model handling, sampling behavior, memory budget, and metadata unless a change is directly required by the task.
- Coordinate file ownership when working in parallel. One coordinator owns shared application-state and navigation integration. Independent persistence work should expose a small interface and avoid editing those shared files concurrently.
- Run checks appropriate to the change. Persistence needs meaningful save/reload and metadata tests. Distinguish build, interface, storage, and actual generation results in progress reports. Commit changes in focused units and keep completion status in `docs/FORK-PLAN.md` accurate.
