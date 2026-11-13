import SwiftUI

@main
struct StickyDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(NoteStore.shared)
        } label: {
            Image(systemName: "note.text")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated { PinManager.shared.start(); PasteRouter.install() }
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { NoteStore.shared.saveNow() }
    }
}
