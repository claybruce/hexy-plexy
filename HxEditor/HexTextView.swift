import Cocoa
import SwiftUI
import Combine

class HexTextView: NSView {
    // Data Source
    weak var hexDocument: HexDocument? {
        didSet {
            if let doc = hexDocument, doc.buffer.count == 0, currentCursor == nil {
                currentCursor = 0
                currentSelection = [0]
                currentAnchor = 0
            }
            updateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    weak var bookmarkManager: BookmarkManager? {
        didSet {
            setupBookmarkObserver()
            needsDisplay = true
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    var byteGrouping: Int = 8 {
        didSet {
            if oldValue != byteGrouping {
                needsDisplay = true
            }
        }
    }
    var isHexInputMode: Bool = false
    var isOverwriteMode: Bool = false
    
    // State
    var currentSelection: Set<Int> = [] {
        didSet {
            pendingHexNibble = nil
            needsDisplay = true
        }
    }
    var currentCursor: Int? {
        didSet {
            pendingHexNibble = nil
            needsDisplay = true
        }
    }
    var currentAnchor: Int?
    
    // Callbacks
    var onSelectionChanged: ((Set<Int>) -> Void)?
    var onCursorChanged: ((Int?) -> Void)?
    
    // Layout Constants
    private let bytesPerRow = 16
    private let lineHeight: CGFloat = 20.0
    private let charWidth: CGFloat = 7.0 // Approximate for monospaced font
    private let gutterWidth: CGFloat = 80.0
    private let hexStart: CGFloat = 90.0
    private let verticalPadding: CGFloat = 10.0 // Top and bottom padding
    
    // Fonts
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    
    // Color Cache
    private var colorCache: [NSColor] = []
    private var lastColorScheme: NSAppearance?
    
    // Input State
    private var pendingHexNibble: UInt8?
    
    private func setupBookmarkObserver() {
        cancellables.removeAll()
        bookmarkManager?.$bookmarks
            .sink { [weak self] _ in
                self?.needsDisplay = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(named: "BackgroundColor")?.cgColor ?? NSColor.textBackgroundColor.cgColor
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // Claim focus when added to a window
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        colorCache.removeAll()
        needsDisplay = true
    }
    
    // MARK: - Layout & Drawing
    
    private func updateIntrinsicContentSize() {
        guard let document = hexDocument else { return }
        let totalLines = CGFloat((document.buffer.count + bytesPerRow - 1) / bytesPerRow)
        // Add one extra line for EOF cursor (when last row is full, EOF cursor is on next line)
        let height = (totalLines + 1) * lineHeight + (verticalPadding * 2)
        // Width calculation - must match fixed layout in draw()
        let addressWidth = 10 * charWidth
        let hexByteWidth = 3 * charWidth
        let hexBlockWidth = (CGFloat(bytesPerRow) * hexByteWidth) + (CGFloat(bytesPerRow / byteGrouping) * charWidth)
        let asciiWidth = CGFloat(bytesPerRow) * charWidth
        
        // Fixed positions matching draw method
        let hexSectionStartX = addressWidth + 20.0
        let asciiStartX = hexSectionStartX + hexBlockWidth + 20.0
        let width = asciiStartX + asciiWidth + 20.0
        
        self.frame.size = NSSize(width: max(width, self.superview?.bounds.width ?? width), height: height)
        self.invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        guard let document = hexDocument else { return NSSize(width: 600, height: 100) }
        let totalLines = CGFloat((document.buffer.count + bytesPerRow - 1) / bytesPerRow)
        // Add one extra line for EOF cursor (when last row is full, EOF cursor is on next line)
        return NSSize(width: 600, height: (totalLines + 1) * lineHeight + (verticalPadding * 2))
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let document = hexDocument else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Update colors if needed
        if colorCache.isEmpty {
            updateColorCache()
        }
        
        // Fill background
        NSColor(named: "BackgroundColor")?.setFill() ?? NSColor.textBackgroundColor.setFill()
        context.fill(dirtyRect)
        
        let buffer = document.buffer
        let firstLine = max(0, Int(dirtyRect.minY / lineHeight))
        let lastLine = max(firstLine, Int(dirtyRect.maxY / lineHeight))
        
        let _: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let addressAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Use FIXED layout positions to prevent shifting when bounds change
        let addressWidth = 10 * charWidth
        let hexByteWidth = 3 * charWidth
        
        // Calculate total width of hex block
        let hexBlockWidth = (CGFloat(bytesPerRow) * hexByteWidth) + (CGFloat(bytesPerRow / byteGrouping) * charWidth)
        
        // Use fixed positions - no dynamic centering
        let addressX: CGFloat = 5.0
        let hexSectionStartX: CGFloat = addressWidth + 20.0  // Fixed offset from address
        let asciiStartX: CGFloat = hexSectionStartX + hexBlockWidth + 20.0  // Fixed offset from hex
        
        // Draw Separator Line (Address | Hex)
        context.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.0)
        let sepX = addressWidth + 5
        context.move(to: CGPoint(x: sepX, y: dirtyRect.minY))
        context.addLine(to: CGPoint(x: sepX, y: dirtyRect.maxY))
        context.strokePath()
        
        // Draw Separator Line (Hex | ASCII)
        let asciiSepX = asciiStartX - 10
        context.move(to: CGPoint(x: asciiSepX, y: dirtyRect.minY))
        context.addLine(to: CGPoint(x: asciiSepX, y: dirtyRect.maxY))
        context.strokePath()
        
        // Draw visible lines
        for line in firstLine...lastLine {
            let byteIndex = line * bytesPerRow
            // Break if beyond buffer, but allow drawing line 0 for empty file (to show address 00000000)
            if byteIndex >= buffer.count && (buffer.count > 0 || line > 0) { break }
            
            let y = CGFloat(line) * lineHeight + verticalPadding
            
            // Draw Address
            let addressString = String(format: "%08X", byteIndex) as NSString
            addressString.draw(at: NSPoint(x: addressX, y: y), withAttributes: addressAttributes)
            
            // Draw Hex and ASCII
            for i in 0..<bytesPerRow {
                let currentByteIndex = byteIndex + i
                if currentByteIndex >= buffer.count { break }
                
                let byte = buffer[currentByteIndex]
                
                // Calculate Hex Position
                let groupCount = i / byteGrouping
                let hexX = hexSectionStartX + CGFloat(i) * hexByteWidth + CGFloat(groupCount) * charWidth
                
                // Calculate ASCII Position
                let asciiX = asciiStartX + CGFloat(i) * charWidth
                
                // Selection Highlight
                if currentSelection.contains(currentByteIndex) {
                    // Make selection more noticeable but elegant
                    NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4).setFill()
                    
                    // Hex Selection Logic
                    var width = (2.0 * charWidth) + 4.0 // Default tight width for "FF"
                    let x = hexX - 2.0 // Slight padding left
                    
                    // Check if right neighbor is selected to connect them
                    let isRightSelected = currentSelection.contains(currentByteIndex + 1) && (i < bytesPerRow - 1)
                    if isRightSelected {
                        // Calculate distance to next byte to span the gap
                        let nextGroupCount = (i + 1) / byteGrouping
                        let currentGroupCount = i / byteGrouping
                        let dist = hexByteWidth + CGFloat(nextGroupCount - currentGroupCount) * charWidth
                        width = dist
                    }
                    
                    let hexRect = NSRect(x: x, y: y, width: width, height: lineHeight)
                    // Use a rounded rect for a softer look, but only if it's a single/end block?
                    // For simplicity and solid merging, standard fill is best.
                    // To make it look "pill-like" for the whole run is complex without path merging.
                    // Let's stick to standard fill but with better geometry.
                    let path = NSBezierPath(roundedRect: hexRect, xRadius: 2, yRadius: 2)
                    path.fill()
                    
                    // ASCII Selection
                    // ASCII chars are contiguous, so standard rect is fine.
                    let asciiRect = NSRect(x: asciiX, y: y, width: charWidth, height: lineHeight)
                    context.fill(asciiRect)
                }
                
                // Cursor Highlight
                if currentCursor == currentByteIndex {
                    context.setStrokeColor(NSColor.textColor.cgColor)
                    context.setLineWidth(1.0)
                    // Adjust cursor rect to match new selection geometry
                    let hexRect = NSRect(x: hexX - 2.0, y: y, width: (2.0 * charWidth) + 4.0, height: lineHeight)
                    context.stroke(hexRect)
                    
                    // Also highlight ASCII cursor
                    let asciiRect = NSRect(x: asciiX, y: y, width: charWidth, height: lineHeight)
                    context.stroke(asciiRect)
                }
                
                // Bookmark Highlight
                if let bm = bookmarkManager, bm.hasBookmark(at: currentByteIndex) {
                    context.setStrokeColor(NSColor.systemYellow.cgColor)
                    context.setLineWidth(2.0)
                    let hexRect = NSRect(x: hexX - 2.0, y: y, width: (2.0 * charWidth) + 4.0, height: lineHeight)
                    context.stroke(hexRect)
                }
                
                // Draw Hex
                // Use ByteColorScheme hex string if available, else format
                let hexString = ByteColorScheme.hexString(for: byte) as NSString
                
                // Use colored text for hex
                let color = colorCache.count > Int(byte) ? colorCache[Int(byte)] : NSColor.textColor
                let coloredAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                
                hexString.draw(at: NSPoint(x: hexX, y: y), withAttributes: coloredAttrs)
                
                // Draw ASCII
                let char: String
                if byte >= 32 && byte <= 126 {
                    char = String(UnicodeScalar(byte))
                } else {
                    char = "."
                }
                (char as NSString).draw(at: NSPoint(x: asciiX, y: y), withAttributes: coloredAttrs)
            }
        }
        
        // Draw cursor if it's at EOF (one past the last byte)
        // Allow drawing if buffer is empty (cursor at 0)
        if let cursor = currentCursor, cursor == buffer.count {
            let line = cursor / bytesPerRow
            if line >= firstLine && line <= lastLine {
                let i = cursor % bytesPerRow
                let y = CGFloat(line) * lineHeight + verticalPadding
                
                // Calculate positions
                let groupCount = i / byteGrouping
                let hexX = hexSectionStartX + CGFloat(i) * hexByteWidth + CGFloat(groupCount) * charWidth
                let asciiX = asciiStartX + CGFloat(i) * charWidth
                
                // Draw Hex Cursor
                context.setStrokeColor(NSColor.textColor.cgColor)
                context.setLineWidth(1.0)
                let hexRect = NSRect(x: hexX - 2.0, y: y, width: (2.0 * charWidth) + 4.0, height: lineHeight)
                context.stroke(hexRect)
                
                // Draw ASCII Cursor
                let asciiRect = NSRect(x: asciiX, y: y, width: charWidth, height: lineHeight)
                context.stroke(asciiRect)
            }
        }
    }
    
    private func updateColorCache() {
        colorCache.removeAll()
        let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let scheme: ColorScheme = isDark ? .dark : .light
        
        for i in 0...255 {
            let color = ByteColorScheme.color(for: UInt8(i), colorScheme: scheme)
            colorCache.append(NSColor(color))
        }
    }
    
    // MARK: - Interaction
    
    override func mouseDown(with event: NSEvent) {
        guard hexDocument != nil else { return }
        let point = self.convert(event.locationInWindow, from: nil)
        
        if let index = indexAt(point: point) {
            currentSelection = [index]
            currentCursor = index
            currentAnchor = index
            onSelectionChanged?(currentSelection)
            onCursorChanged?(currentCursor)
            needsDisplay = true
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard hexDocument != nil, let anchor = currentAnchor else { return }
        let point = self.convert(event.locationInWindow, from: nil)
        
        if let index = indexAt(point: point) {
            let range = min(anchor, index)...max(anchor, index)
            currentSelection = Set(range)
            currentCursor = index
            onSelectionChanged?(currentSelection)
            onCursorChanged?(currentCursor)
            needsDisplay = true
            autoscroll(with: event)
        }
    }
    
    private func indexAt(point: NSPoint) -> Int? {
        // Account for vertical padding
        let adjustedY = point.y - verticalPadding
        let line = Int(adjustedY / lineHeight)
        if line < 0 { return nil }
        
        // Use FIXED positions matching draw method
        let addressWidth = 10 * charWidth
        let hexByteWidth = 3 * charWidth
        let hexBlockWidth = (CGFloat(bytesPerRow) * hexByteWidth) + (CGFloat(bytesPerRow / byteGrouping) * charWidth)
        
        let hexSectionStartX: CGFloat = addressWidth + 20.0  // Fixed offset from address
        let asciiStartX: CGFloat = hexSectionStartX + hexBlockWidth + 20.0  // Fixed offset from hex
        
        // Check if in Hex area
        if point.x >= hexSectionStartX && point.x < asciiStartX {
            let relativeX = point.x - hexSectionStartX
            for i in 0..<bytesPerRow {
                let groupCount = i / byteGrouping
                let hexX = CGFloat(i) * hexByteWidth + CGFloat(groupCount) * charWidth
                if relativeX >= hexX && relativeX < hexX + hexByteWidth {
                    let index = line * bytesPerRow + i
                    // Allow selecting EOF position (one past the end)
                    return index <= (hexDocument?.buffer.count ?? 0) ? index : nil
                }
            }
        }
        
        // Check if in ASCII area
        if point.x >= asciiStartX {
            let relativeX = point.x - asciiStartX
            let col = Int(relativeX / charWidth)
            if col >= 0 && col < bytesPerRow {
                let index = line * bytesPerRow + col
                // Allow selecting EOF position (one past the end)
                return index <= (hexDocument?.buffer.count ?? 0) ? index : nil
            }
        }
        
        return nil
    }
    
    // MARK: - Keyboard
    
    override func keyDown(with event: NSEvent) {
        guard let document = hexDocument else { return }
        
        let cursor = currentCursor ?? 0
        var newCursor = cursor
        var handled = false
        
        // Handle special keys that should be ignored or have no effect
        if event.keyCode == 51 { // Delete/Backspace
            handleBackspace()
            return
        }
        
        if event.keyCode == 117 { // Forward Delete
            handleDelete()
            return
        }
        
        if event.keyCode == 53 { // Escape - no effect
            return
        }

        // Navigation
        if let specialKey = event.specialKey {
            handled = true
            switch specialKey {
            case .upArrow: newCursor = max(0, cursor - bytesPerRow)
            case .downArrow: newCursor = min(document.buffer.count, cursor + bytesPerRow)
            case .leftArrow: newCursor = max(0, cursor - 1)
            case .rightArrow: newCursor = min(document.buffer.count, cursor + 1)
            case .pageUp: newCursor = max(0, cursor - bytesPerRow * 16)
            case .pageDown: newCursor = min(document.buffer.count, cursor + bytesPerRow * 16)
            case .home: newCursor = 0
            case .end: newCursor = document.buffer.count
            default: handled = false
            }
        }
        
        if handled {
            // Shift for selection
            if event.modifierFlags.contains(.shift) {
                let anchor = currentAnchor ?? cursor
                let range = min(anchor, newCursor)...max(anchor, newCursor)
                currentSelection = Set(range)
                currentAnchor = anchor
            } else {
                currentSelection = [newCursor]
                currentAnchor = newCursor
            }
            
            currentCursor = newCursor
            onSelectionChanged?(currentSelection)
            onCursorChanged?(currentCursor)
            scrollToCursor()
            needsDisplay = true
            return
        }
        
        // Editing & Commands
        if let char = event.charactersIgnoringModifiers?.first {
            if event.modifierFlags.contains(.command) {
                if char == "c" {
                    if event.modifierFlags.contains(.shift) {
                        copyAsciiSelection()
                    } else {
                        copySelection()
                    }
                } else if char == "v" {
                    if event.modifierFlags.contains(.shift) {
                        pasteAsAscii()
                    } else {
                        pasteAsHex()
                    }
                } else if char == "a" {
                    // Select All
                    currentSelection = Set(0..<document.buffer.count)
                    currentAnchor = 0
                    currentCursor = document.buffer.count - 1
                    onSelectionChanged?(currentSelection)
                    onCursorChanged?(currentCursor)
                    needsDisplay = true
                } else if char == "b" {
                    if let cursor = currentCursor {
                        toggleBookmark(at: cursor)
                    }
                } else if char == "0" {
                    zeroOutSelection()
                }
            } else if !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                // Typing
                handleInput(char, event: event)
            }
        }
    }
    
    private func handleInput(_ char: Character, event: NSEvent) {
        guard let document = hexDocument, let cursor = currentCursor else { return }
        
        if isHexInputMode {
            if let hexValue = char.hexDigitValue {
                let nibble = UInt8(hexValue)
                
                if let pending = pendingHexNibble {
                    // Second nibble: combine and insert/replace
                    let byte = (pending << 4) | nibble
                    pendingHexNibble = nil
                    
                    if currentSelection.count > 1 {
                        // Multi-selection replace
                        let sortedSelection = currentSelection.sorted()
                        let insertionIndex = sortedSelection.first ?? cursor
                        
                        undoManager?.beginUndoGrouping()
                        document.delete(indices: sortedSelection, undoManager: undoManager)
                        document.insert(byte, at: insertionIndex, undoManager: undoManager)
                        document.delete(indices: sortedSelection, undoManager: undoManager)
                        document.insert(byte, at: insertionIndex, undoManager: undoManager)
                        undoManager?.endUndoGrouping()
                        
                        if document.readOnly { return }
                        
                        let newCursor = insertionIndex + 1
                        currentCursor = newCursor
                        currentSelection = [newCursor]
                        currentAnchor = newCursor
                    } else {
                        // Single cursor
                        if isOverwriteMode && cursor < document.buffer.count {
                            document.replace(at: cursor, with: byte, undoManager: undoManager)
                        } else {
                            document.insert(byte, at: cursor, undoManager: undoManager)
                        }
                        
                        if document.readOnly { return }
                        
                        moveCursorRight()
                    }
                    // moveCursorRight already updates selection, cursor, scrolls, and triggers display
                } else {
                    // First nibble: store it
                    pendingHexNibble = nibble
                }
            }
        } else {
            if let asciiValue = char.asciiValue {
                // Check for selection overwrite
                if currentSelection.count > 1 {
                    let sortedSelection = currentSelection.sorted()
                    let insertionIndex = sortedSelection.first ?? cursor
                    
                    // Group undo for atomic operation
                    undoManager?.beginUndoGrouping()
                    
                    // Delete selected range
                    document.delete(indices: sortedSelection, undoManager: undoManager)
                    
                    // Insert new character
                    document.insert(asciiValue, at: insertionIndex, undoManager: undoManager)
                    
                    undoManager?.endUndoGrouping()
                    
                    if document.readOnly { return }
                    
                    // Update cursor to be after the inserted byte
                    let newCursor = insertionIndex + 1
                    currentCursor = newCursor
                    currentSelection = [newCursor]
                    currentAnchor = newCursor
                    onSelectionChanged?(currentSelection)
                    onCursorChanged?(currentCursor)
                    scrollToCursor()
                    needsDisplay = true
                } else {
                    // Standard single cursor behavior
                    if isOverwriteMode && cursor < document.buffer.count {
                        document.replace(at: cursor, with: asciiValue, undoManager: undoManager)
                    } else {
                        document.insert(asciiValue, at: cursor, undoManager: undoManager)
                    }
                    
                    if document.readOnly { return }
                    
                    moveCursorRight()
                }
                // moveCursorRight already updates selection, cursor, scrolls, and triggers display
            }
        }
    }
    
    private func handleBackspace() {
        guard let document = hexDocument, let cursor = currentCursor else { return }
        
        if currentSelection.count > 1 {
            // Check if selection is contiguous
            let sortedSelection = currentSelection.sorted()
            let isContiguous = sortedSelection.last! - sortedSelection.first! == sortedSelection.count - 1
            
            let newCursorIndex = sortedSelection.first ?? 0
            
            if isContiguous {
                let range = sortedSelection.first!..<(sortedSelection.last! + 1)
                document.delete(range: range, undoManager: undoManager)
            } else {
                document.delete(indices: sortedSelection, undoManager: undoManager)
            }
            
            if document.readOnly { return }
            
            // Move cursor to the start of where the deletion happened
            let newCursor = min(newCursorIndex, document.buffer.count) // Ensure valid
            currentCursor = newCursor
            currentSelection = [newCursor]
            currentAnchor = newCursor
            onSelectionChanged?(currentSelection)
            onCursorChanged?(currentCursor)
            scrollToCursor()
            needsDisplay = true
        } else {
            // Standard backspace behavior (delete previous char)
            // Ensure cursor is within valid bounds before attempting delete
            if cursor > 0 && cursor <= document.buffer.count && cursor - 1 < document.buffer.count {
                document.delete(at: cursor - 1, undoManager: undoManager)
                if document.readOnly { return }
                moveCursorLeft()
            }
        }
    }
    
    private func handleDelete() {
        guard let document = hexDocument, let cursor = currentCursor else { return }
        
        if currentSelection.count > 1 {
            // Multi-selection: delete all selected bytes (same as Backspace)
            let sortedSelection = currentSelection.sorted()
            let isContiguous = sortedSelection.last! - sortedSelection.first! == sortedSelection.count - 1
            
            let newCursorIndex = sortedSelection.first ?? 0
            
            if isContiguous {
                let range = sortedSelection.first!..<(sortedSelection.last! + 1)
                document.delete(range: range, undoManager: undoManager)
            } else {
                document.delete(indices: sortedSelection, undoManager: undoManager)
            }
            
            if document.readOnly { return }
            
            let newCursor = min(newCursorIndex, max(0, document.buffer.count - 1))
            currentCursor = newCursor
            currentSelection = [newCursor]
            currentAnchor = newCursor
            onSelectionChanged?(currentSelection)
            onCursorChanged?(currentCursor)
            scrollToCursor()
            needsDisplay = true
        } else {
            // Forward delete: delete byte at cursor position
            if cursor < document.buffer.count {
                document.delete(at: cursor, undoManager: undoManager)
                if document.readOnly { return }
                // Cursor stays at same position (now pointing to next byte)
                let newCursor = min(cursor, max(0, document.buffer.count - 1))
                currentCursor = newCursor
                currentSelection = [newCursor]
                currentAnchor = newCursor
                onSelectionChanged?(currentSelection)
                onCursorChanged?(currentCursor)
                scrollToCursor()
                needsDisplay = true
            }
        }
    }
    
    private func moveCursorRight() {
        guard let document = hexDocument, let cursor = currentCursor else { return }
        // Allow moving to EOF position (one past the end)
        let newCursor = min(document.buffer.count, cursor + 1)
        currentCursor = newCursor
        currentSelection = [newCursor]
        currentAnchor = newCursor
        onSelectionChanged?(currentSelection)
        onCursorChanged?(currentCursor)
        scrollToCursor()
        needsDisplay = true
    }
    
    private func moveCursorLeft() {
        guard let cursor = currentCursor else { return }
        let newCursor = max(0, cursor - 1)
        currentCursor = newCursor
        currentSelection = [newCursor]
        currentAnchor = newCursor
        onSelectionChanged?(currentSelection)
        onCursorChanged?(currentCursor)
        scrollToCursor()
        needsDisplay = true
    }
    
    private func copySelection() {
        guard let document = hexDocument else { return }
        let sortedSelection = currentSelection.sorted()
        if sortedSelection.isEmpty { return }
        
        var text = ""
        for index in sortedSelection {
            let byte = document.buffer[index]
            text += String(format: "%02X ", byte)
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text.trimmingCharacters(in: .whitespaces), forType: .string)
    }
    
    private func copyAsciiSelection() {
        guard let document = hexDocument else { return }
        let sortedSelection = currentSelection.sorted()
        if sortedSelection.isEmpty { return }
        
        var text = ""
        for index in sortedSelection {
            let byte = document.buffer[index]
            if byte >= 32 && byte <= 126 {
                text += String(UnicodeScalar(byte))
            } else {
                text += "."
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func scrollToCursor() {
        guard let cursor = currentCursor else { return }
        let line = cursor / bytesPerRow
        
        // Special handling for first line - always ensure we're at the very top
        if line == 0 {
            if visibleRect.minY != 0 {
                scroll(NSPoint(x: visibleRect.minX, y: 0))
            }
            return
        }
        
        let y = CGFloat(line) * lineHeight + verticalPadding
        
        // Check if line is already fully visible vertically
        if y >= visibleRect.minY && (y + lineHeight) <= visibleRect.maxY {
            return
        }
        
        let rect = NSRect(x: 0, y: y, width: bounds.width, height: lineHeight)
        scrollToVisible(rect)
    }

    func regenerateContent() {
        updateIntrinsicContentSize()
        needsDisplay = true
    }
    
    func setSelection(_ selection: Set<Int>, anchor: Int?, cursor: Int?) {
        self.currentSelection = selection
        self.currentAnchor = anchor
        
        if let cursor = cursor {
            self.currentCursor = cursor
        } else if let doc = hexDocument, doc.buffer.count == 0 {
            // Default to 0 for empty document to ensure it's editable
            self.currentCursor = 0
            if self.currentSelection.isEmpty {
                self.currentSelection = [0]
            }
            self.currentAnchor = 0
        } else {
            self.currentCursor = nil
        }
        
        scrollToCursor()
        needsDisplay = true
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Copy Hex", action: #selector(copySelectionMenu), keyEquivalent: "c")
        
        let copyAsciiItem = NSMenuItem(title: "Copy ASCII", action: #selector(copyAsciiSelectionMenu), keyEquivalent: "c")
        copyAsciiItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(copyAsciiItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: "Paste Hex", action: #selector(pasteHexMenu), keyEquivalent: "v")
        
        let pasteAsciiItem = NSMenuItem(title: "Paste ASCII", action: #selector(pasteAsciiMenu), keyEquivalent: "v")
        pasteAsciiItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(pasteAsciiItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: "Zero Out", action: #selector(zeroOutMenu), keyEquivalent: "0")
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: "Toggle Bookmark", action: #selector(toggleBookmarkMenu), keyEquivalent: "b")
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: "Select All", action: #selector(selectAllMenu), keyEquivalent: "a")
        
        return menu
    }
    
    @objc private func copySelectionMenu() {
        copySelection()
    }
    
    @objc private func copyAsciiSelectionMenu() {
        copyAsciiSelection()
    }
    
    @objc private func pasteHexMenu() {
        pasteAsHex()
    }
    
    @objc private func pasteAsciiMenu() {
        pasteAsAscii()
    }
    
    @objc private func zeroOutMenu() {
        zeroOutSelection()
    }
    
    @objc private func toggleBookmarkMenu() {
        guard let cursor = currentCursor else { return }
        toggleBookmark(at: cursor)
    }
    
    @objc private func selectAllMenu() {
        guard let document = hexDocument else { return }
        currentSelection = Set(0..<document.buffer.count)
        currentAnchor = 0
        currentCursor = document.buffer.count - 1
        onSelectionChanged?(currentSelection)
        onCursorChanged?(currentCursor)
        needsDisplay = true
    }
    
    private func pasteAsHex() {
        let pasteboard = NSPasteboard.general
        guard let string = pasteboard.string(forType: .string) else { return }
        
        // Filter for valid hex characters
        let hexChars = string.uppercased().filter { "0123456789ABCDEF".contains($0) }
        
        var bytes: [UInt8] = []
        var currentIndex = hexChars.startIndex
        
        while currentIndex < hexChars.endIndex {
            let nextIndex = hexChars.index(after: currentIndex)
            if nextIndex < hexChars.endIndex {
                let pair = hexChars[currentIndex...nextIndex]
                if let byte = UInt8(pair, radix: 16) {
                    bytes.append(byte)
                }
                currentIndex = hexChars.index(after: nextIndex)
            } else {
                break
            }
        }
        
        pasteBytes(bytes)
    }
    
    private func pasteAsAscii() {
        let pasteboard = NSPasteboard.general
        guard let string = pasteboard.string(forType: .string) else { return }
        if let data = string.data(using: .utf8) {
            pasteBytes([UInt8](data))
        }
    }
    
    private func pasteBytes(_ bytes: [UInt8]) {
        guard let document = hexDocument, let cursor = currentCursor else { return }
        guard !bytes.isEmpty else { return }
        
        if isOverwriteMode {
            document.replace(bytes: bytes, at: cursor, undoManager: undoManager)
        } else {
            document.insert(bytes: bytes, at: cursor, undoManager: undoManager)
        }
        
        if document.readOnly { return }
        
        let newCursor = cursor + bytes.count
        currentCursor = newCursor
        currentSelection = [newCursor]
        currentAnchor = newCursor
        onSelectionChanged?(currentSelection)
        onCursorChanged?(currentCursor)
        scrollToCursor()
        needsDisplay = true
    }
    
    private func zeroOutSelection() {
        guard let document = hexDocument else { return }
        for index in currentSelection {
            document.replace(at: index, with: 0, undoManager: undoManager)
        }
        if document.readOnly { return }
        needsDisplay = true
    }
    
    private func toggleBookmark(at index: Int) {
        guard let bm = bookmarkManager else { return }
        if bm.hasBookmark(at: index) {
            bm.removeBookmark(at: index)
        } else {
            bm.addBookmark(offset: index, name: "Bookmark at 0x\(String(format: "%X", index))")
        }
    }
}
