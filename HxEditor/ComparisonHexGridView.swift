import SwiftUI
import Combine

struct ComparisonHexGridView: NSViewRepresentable {
    @ObservedObject var document: HexDocument
    var diffResult: EnhancedDiffResult?
    var isLeftSide: Bool
    @Binding var scrollTarget: ComparisonContentView.ScrollTarget?
    @Binding var currentVisibleOffset: Int
    var showOnlyDifferences: Bool
    var currentBlockIndex: Int
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .legacy // Always-visible scrollbars, no auto-hide
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(named: "BackgroundColor") ?? .textBackgroundColor
        
        let textView = ComparisonHexTextView()
        textView.hexDocument = document
        textView.diffResult = diffResult
        textView.isLeftSide = isLeftSide
        textView.showOnlyDifferences = showOnlyDifferences
        
        scrollView.documentView = textView
        
        // Observe scrolling to update currentVisibleOffset
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            context.coordinator.updateVisibleOffset(scrollView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComparisonHexTextView else { return }
        
        // Update properties
        if textView.hexDocument !== document {
            textView.hexDocument = document
        }
        
        // Check if diff result changed (simple check)
        // In a real app we might want deeper equality or just always update if struct changes
        // Since EnhancedDiffResult is a struct, we can just assign it
        textView.diffResult = diffResult
        textView.isLeftSide = isLeftSide
        textView.showOnlyDifferences = showOnlyDifferences
        
        // Handle programmatic scrolling
        if let target = scrollTarget, target.id != context.coordinator.lastScrollTargetId {
            context.coordinator.lastScrollTargetId = target.id
            scrollToOffset(scrollView, offset: target.offset)
        }
    }
    
    private func scrollToOffset(_ scrollView: NSScrollView, offset: Int) {
        guard let textView = scrollView.documentView as? ComparisonHexTextView else { return }
        
        if let y = textView.yPosition(for: offset) {
            // Calculate target origin to center the row
            let scrollViewHeight = scrollView.bounds.height
            let targetY = max(0, y - (scrollViewHeight / 2) + 10)
            
            let newOrigin = NSPoint(x: 0, y: targetY)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(newOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            } completionHandler: {
                // Ensure highlight is triggered on main thread with slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textView.flashHighlight(at: offset)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ComparisonHexGridView
        var lastScrollTargetId: UUID?
        
        init(_ parent: ComparisonHexGridView) {
            self.parent = parent
        }
        
        func updateVisibleOffset(_ scrollView: NSScrollView) {
            guard let textView = scrollView.documentView as? ComparisonHexTextView else { return }
            let visibleRect = scrollView.documentVisibleRect
            let y = visibleRect.minY
            
            if let offset = textView.offset(at: y) {
                DispatchQueue.main.async {
                    // Only update if significantly different to avoid loop?
                    // Or just update.
                    self.parent.currentVisibleOffset = offset
                }
            }
        }
    }
}
