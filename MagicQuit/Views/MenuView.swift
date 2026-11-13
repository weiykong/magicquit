import SwiftUI
import AppKit

struct MenuView: View {
    @EnvironmentObject private var manager: RunningAppsManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    /// Popover content width. Also the fingerprint `menuBarPopoverWindow()`
    /// uses to recognise the popover window, so keep the two in sync.
    static let menuWidth: CGFloat = 320

    private var sortedApps: [RunningAppsManager.TrackedApp] {
        manager.tracked.values.sorted {
            ($0.app.localizedName ?? "").localizedCaseInsensitiveCompare($1.app.localizedName ?? "") == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let rows = VStack(spacing: 2) {
                    ForEach(sortedApps) { entry in
                        AppRowView(entry: entry, now: context.date)
                    }
                }
                if sortedApps.count > 12 {
                    ScrollView {
                        rows
                    }
                    .frame(height: 420)
                } else {
                    rows
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Divider()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            if settings.quitOnLastWindowClosed && !WindowWatcher.isTrusted {
                MenuActionButton(title: "Grant Accessibility Access…") {
                    WindowWatcher.promptForAccess()
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            MenuActionButton(title: "Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            MenuActionButton(title: "Quit MagicQuit") {
                NSApp.terminate(nil)
            }
            .padding(.bottom, 6)
        }
        .frame(width: Self.menuWidth)
        // The window-style menu bar popover keeps its previous height, so after
        // the list shrinks (apps quit, or the Accessibility row disappears) it
        // leaves blank bands above and below the content, because the vibrancy
        // material is only drawn behind the shrunken content. Report the
        // content's ideal height and shrink the popover to match.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { resizePopover(toHeight: proxy.size.height) }
                    .onChange(of: proxy.size.height) { _, height in resizePopover(toHeight: height) }
            }
        }
    }

    /// Shrinks the menu bar popover window to the content's height. Only shrinks:
    /// growing is left to the system, which already expands the popover for new rows.
    ///
    /// The resize is deferred: SwiftUI's own `.window` popover sizing runs at the
    /// end of the same update cycle, and resizing inline raced it — when a row
    /// disappeared (an app quit) it could leave the window's vibrancy chrome a
    /// frame behind the shrunk NSWindow. Running after SwiftUI's own pass fixes
    /// that.
    ///
    /// NOTE: this silently did nothing for a while, because `menuBarPopoverWindow()`
    /// filtered on `window.level == .statusBar` while macOS 26 puts the popover at
    /// `.popUpMenu` (101). Measured live: the popover kept its 137 pt height after
    /// a row disappeared and showed two transparent bands (top ~10 pt, bottom
    /// ~15 pt). If the bands come back, check the window match first, the timing
    /// second.
    private func resizePopover(toHeight height: CGFloat) {
        DispatchQueue.main.async {
            guard height > 1, let window = menuBarPopoverWindow() else { return }
            guard window.frame.height - height > 1 else { return }
            var frame = window.frame
            // Keep the top edge pinned under the menu bar; only the bottom moves up.
            frame.origin.y += frame.size.height - height
            frame.size.height = height
            window.setFrame(frame, display: true, animate: false)
        }
    }

    /// The popover SwiftUI creates for a `.window`-style menu bar extra: a
    /// borderless, non-activating window (its class name is private, so match on
    /// behavior instead).
    ///
    /// Do NOT match on `window.level`: it is not stable across macOS versions.
    /// Measured live on macOS 26 the popover sits at level 101
    /// (`.popUpMenu`), not `.statusBar` (25), so a level check silently matches
    /// nothing, `resizePopover` bails at its guard, and the popover keeps the
    /// height it had before the list shrank — which renders as two transparent
    /// bands, one above and one below the content, because the vibrancy
    /// material is only drawn behind the shrunken content.
    ///
    /// Match on the panel style plus the popover's own content width instead.
    /// The countdown banner is also a borderless non-activating panel but is
    /// 290 pt wide, so the width check keeps it out.
    private func menuBarPopoverWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.styleMask.contains(.borderless)
                && window.styleMask.contains(.nonactivatingPanel)
                && window.isVisible
                && abs(window.frame.width - Self.menuWidth) < 2
        }
    }
}

struct MenuActionButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 5).fill(isHovered ? Color.accentColor : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .onHover { isHovered = $0 }
    }
}
