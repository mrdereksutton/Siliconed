// **The Prompt Lab in a window of its own** (issue 16): full-bleed darkroom studio chrome without a stock
// gray macOS titlebar, as large as the hand makes it — the text grows with the window.

import AppKit
import SwiftUI

@MainActor
final class LabWindow: NSObject, NSWindowDelegate {
    static let shared = LabWindow()
    private var window: NSWindow?

    var isShown: Bool { window?.isVisible == true }

    /// Opens or focuses the Prompt Lab in its own full-bleed Studio window.
    func openStudio() {
        let lab = LabModel.shared
        lab.detached = true
        if lab.unfolded {
            show(lab)
        } else {
            lab.unfold()
        }
    }

    func refreshChrome() {
        window?.backgroundColor = Palette.columnInk
    }

    func show(_ model: LabModel) {
        if let window {
            window.backgroundColor = Palette.columnInk
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: true)
        w.title = String(localized: "Prompt Lab")
        let toolbar = NSToolbar(identifier: "SiliconedLabChrome")
        toolbar.allowsUserCustomization = false
        w.toolbar = toolbar
        w.toolbarStyle = .unified
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.titlebarSeparatorStyle = .none
        w.backgroundColor = Palette.columnInk
        w.isReleasedWhenClosed = false
        w.isRestorable = false
        w.contentMinSize = NSSize(width: 540, height: 380)
        w.delegate = self
        let host = NSHostingController(rootView: LabView(model: model, inWindow: true))
        host.sizingOptions = []
        w.contentViewController = host
        w.setContentSize(NSSize(width: 780, height: 540))
        w.center()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    /// Out of sight, kept for the session: it comes back with its frame.
    func hide() { window?.orderOut(nil) }

    /// The close button is the chevron's fold: `fold` orders the window out.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        LabModel.shared.fold()
        return false
    }
}
