import SwiftUI
import AppKit

struct MenuView: View {
    @EnvironmentObject private var manager: RunningAppsManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

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
        .frame(width: 320)
        // The window-style menu bar popover keeps its previous height, so after
        // the list shrinks (apps quit, or the Accessibility row disappears) it
        // leaves a blank gap below the content. Report the content's ideal
        // height and shrink the popover to match.
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
    private func resizePopover(toHeight height: CGFloat) {
        guard height > 1, let window = menuBarPopoverWindow() else { return }
        guard window.frame.height - height > 1 else { return }
        var frame = window.frame
        // Keep the top edge pinned under the menu bar; only the bottom moves up.
        frame.origin.y += frame.size.height - height
        frame.size.height = height
        window.setFrame(frame, display: true, animate: false)
    }

    /// The popover SwiftUI creates for a `.window`-style menu bar extra: a
    /// borderless, non-activating window (its class name is private, so match on
    /// behavior instead).
    private func menuBarPopoverWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.styleMask.contains(.borderless)
                && window.styleMask.contains(.nonactivatingPanel)
                && window.level == .statusBar
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
