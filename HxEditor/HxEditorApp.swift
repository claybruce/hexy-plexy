//
//  HxEditorApp.swift
//  HxEditor
//
//  Created by guru on 23.11.2025.
//

import SwiftUI

@main
struct HxEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        DocumentGroup(newDocument: { HexDocument() }) { configuration in
            ContentView(document: configuration.document)
        }
        .commands {
            // Ensure proper File menu with New command
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasFinishedLaunching = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true
    }
    
    func application(_ app: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return false
    }
    
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no windows are visible, create a new document
        if !flag {
            // Check if an Open Panel is already displayed to avoid duplicates
            let hasOpenPanel = NSApp.windows.contains { $0 is NSOpenPanel && $0.isVisible }
            if !hasOpenPanel {
                NSDocumentController.shared.openDocument(nil)
            }
        }
        return true
    }
    

}
