import SwiftUI
import Combine

struct HexGridView: NSViewRepresentable {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isOverwriteMode: Bool
    @Binding var hexInputMode: Bool
    var byteGrouping: Int
    @Binding var showSearch: Bool
    @Binding var selectionAnchor: Int?
    @Binding var cursorIndex: Int?
    @ObservedObject var bookmarkManager: BookmarkManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .legacy // Always-visible scrollbars, no auto-hide
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(named: "BackgroundColor") ?? .textBackgroundColor
        
        let textView = HexTextView()
        textView.hexDocument = document
        textView.bookmarkManager = bookmarkManager
        textView.byteGrouping = byteGrouping
        textView.isHexInputMode = hexInputMode
        textView.isOverwriteMode = isOverwriteMode
        
        // Set up callbacks
        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.onSelectionChanged = { [weak coordinator] newSelection in
            coordinator?.updateSelection(newSelection)
        }
        
        textView.onCursorChanged = { [weak coordinator] newCursor in
            coordinator?.updateCursor(newCursor)
        }
        
        scrollView.documentView = textView
        textView.regenerateContent()
        
        // Subscribe to document changes
        context.coordinator.setupDocumentObserver()
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HexTextView else { return }
        
        // Update document reference
        if textView.hexDocument !== document {
            textView.hexDocument = document
            textView.bookmarkManager = bookmarkManager
            textView.regenerateContent()
            context.coordinator.setupDocumentObserver()
        }
        
        // Update configuration
        if textView.byteGrouping != byteGrouping {
            textView.byteGrouping = byteGrouping
        }
        
        textView.isHexInputMode = hexInputMode
        textView.isOverwriteMode = isOverwriteMode
        
        // Sync selection from SwiftUI state
        // Skip sync if we recently updated cursor locally (within 100ms) to avoid cursor jumping during rapid input
        let skipCursorSync = context.coordinator.lastLocalCursorUpdate.map { Date().timeIntervalSince($0) < 0.1 } ?? false
        
        if !skipCursorSync && (textView.currentSelection != selection || textView.currentCursor != cursorIndex) {
            textView.setSelection(selection, anchor: selectionAnchor, cursor: cursorIndex)
        }
    }
    
    class Coordinator: NSObject {
        var parent: HexGridView
        var cancellables = Set<AnyCancellable>()
        weak var textView: HexTextView?
        fileprivate var pendingRegenerationTask: DispatchWorkItem?
        fileprivate var lastLocalCursorUpdate: Date?
        
        init(_ parent: HexGridView) {
            self.parent = parent
        }
        
        func setupDocumentObserver() {
            // Clear existing subscriptions to avoid duplicates if called multiple times
            cancellables.removeAll()
            
            parent.document.objectWillChange
                .sink { [weak self] _ in
                    self?.regenerateTextView()
                }
                .store(in: &cancellables)
            
            parent.document.$undoRedoSelectionRange
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] range in
                    self?.handleUndoRedoSelection(range)
                }
                .store(in: &cancellables)
        }
        
        func handleUndoRedoSelection(_ range: Range<Int>) {
            if range.isEmpty {
                // Deletion undo/redo: place cursor at position
                let cursor = range.lowerBound
                parent.selection = [cursor]
                parent.cursorIndex = cursor
                parent.selectionAnchor = cursor
            } else {
                // Insertion/Replacement undo/redo: select range
                parent.selection = Set(range)
                parent.cursorIndex = range.upperBound - 1
                parent.selectionAnchor = range.lowerBound
            }
            // Force immediate update to view
            textView?.setSelection(parent.selection, anchor: parent.selectionAnchor, cursor: parent.cursorIndex)
        }
        
        func regenerateTextView() {
            // Cancel any pending regeneration to avoid stale updates during rapid input
            pendingRegenerationTask?.cancel()
            
            // Schedule new regeneration with delay to batch rapid changes
            let task = DispatchWorkItem { [weak self] in
                self?.textView?.regenerateContent()
            }
            pendingRegenerationTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: task)
        }
        
        func updateSelection(_ newSelection: Set<Int>) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.selection = newSelection
            }
        }
        
        func updateCursor(_ newCursor: Int?) {
            // Track local cursor updates to prevent sync-back during rapid input
            lastLocalCursorUpdate = Date()
            
            DispatchQueue.main.async { [weak self] in
                self?.parent.cursorIndex = newCursor
                if let cursor = newCursor {
                    self?.parent.selectionAnchor = cursor
                }
            }
        }
    }
}
