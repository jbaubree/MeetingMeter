// Sources/MeetingMeter/MenuBar/MenuBarController.swift
import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(rootView: AnyView) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eurosign.circle",
                                   accessibilityDescription: "MeetingMeter")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    /// Sets the menu-bar label text displayed next to the icon. Pass "" to clear.
    func updateLabel(_ text: String) {
        guard let button = statusItem.button else { return }
        button.title = text.isEmpty ? "" : " " + text
    }

    /// Sets the leading icon. Pass nil to keep the default euro symbol.
    func updateIcon(systemName: String?) {
        guard let button = statusItem.button else { return }
        let name = systemName ?? "eurosign.circle"
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "MeetingMeter")
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
