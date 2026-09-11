import Cocoa
import SwiftUI
import Combine

class ComparisonHexTextView: NSView {
    // Data Source
    weak var hexDocument: HexDocument? {
        didSet {
            updateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    var diffResult: EnhancedDiffResult? {
        didSet {
            updateVisibleRows()
            needsDisplay = true
        }
    }
    
    var isLeftSide: Bool = true
    var showOnlyDifferences: Bool = false {
        didSet {
            updateVisibleRows()
            needsDisplay = true
        }
    }
    
    // Layout Constants
    private let bytesPerRow = 16
    private let lineHeight: CGFloat = 20.0
    private let charWidth: CGFloat = 7.0
    
    // Fonts
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    
    // Color Cache
    private var colorCache: [NSColor] = []
    
    // Visible Rows Mapping (for Show Only Differences)
    private struct VisibleRow {
        let bufferOffset: Int
        let isCollapsedRegion: Bool
        let collapsedByteCount: Int
    }
    private var visibleRows: [VisibleRow] = []
    
    // Highlight Animation
    private var highlightLayer: CALayer?
    
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
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        colorCache.removeAll()
        needsDisplay = true
    }
    
    // MARK: - Layout & Drawing
    
    private func updateIntrinsicContentSize() {
        let totalLines: CGFloat
        if showOnlyDifferences {
            totalLines = CGFloat(visibleRows.count)
        } else {
            guard let document = hexDocument else { return }
            totalLines = CGFloat((document.buffer.count + bytesPerRow - 1) / bytesPerRow)
        }
        
        let height = totalLines * lineHeight
        
        // Width calculation (same as HexTextView)
        let addressWidth = 10 * charWidth
        let hexByteWidth = 3 * charWidth
        let asciiWidth = CGFloat(bytesPerRow) * charWidth
        let hexBlockWidth = (CGFloat(bytesPerRow) * hexByteWidth) + (CGFloat(bytesPerRow / 8) * charWidth)
        let minWidth = addressWidth + hexBlockWidth + asciiWidth + 60
        
        self.frame.size = NSSize(width: max(minWidth, self.superview?.bounds.width ?? minWidth), height: height)
        self.invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        let totalLines: CGFloat
        if showOnlyDifferences {
            totalLines = CGFloat(visibleRows.count)
        } else {
            guard let document = hexDocument else { return NSSize(width: 600, height: 100) }
            totalLines = CGFloat((document.buffer.count + bytesPerRow - 1) / bytesPerRow)
        }
        return NSSize(width: 600, height: totalLines * lineHeight)
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
        let byteGrouping = 8
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
            let y = CGFloat(line) * lineHeight
            
            // Determine what to draw based on mode
            let byteIndex: Int
            let isCollapsed: Bool
            let collapsedCount: Int
            
            if showOnlyDifferences {
                if line >= visibleRows.count { break }
                let row = visibleRows[line]
                byteIndex = row.bufferOffset
                isCollapsed = row.isCollapsedRegion
                collapsedCount = row.collapsedByteCount
            } else {
                byteIndex = line * bytesPerRow
                isCollapsed = false
                collapsedCount = 0
            }
            
            if isCollapsed {
                // Draw collapsed region indicator
                NSColor.controlBackgroundColor.withAlphaComponent(0.5).setFill()
                context.fill(NSRect(x: 0, y: y, width: bounds.width, height: lineHeight))
                
                let text = "\(collapsedCount) matching bytes hidden" as NSString
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                text.draw(at: NSPoint(x: hexSectionStartX, y: y + 3), withAttributes: textAttrs)
                continue
            }
            
            if byteIndex >= buffer.count { break }
            
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
                
                // Diff Highlighting
                let (textColor, bgColor) = getByteColors(at: currentByteIndex)
                
                if bgColor != .clear {
                    // Draw background highlight with rounded corners
                    bgColor.setFill()
                    let hexRect = NSRect(x: hexX - 2.0, y: y, width: (2.0 * charWidth) + 4.0, height: lineHeight)
                    
                    // Create a rounded rect path
                    let path = NSBezierPath(roundedRect: hexRect, xRadius: 3.0, yRadius: 3.0)
                    path.fill()
                }
                
                // Draw Hex
                let hexString = ByteColorScheme.hexString(for: byte) as NSString
                let coloredAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
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
    }
    
    private func getByteColors(at offset: Int) -> (NSColor, NSColor) {
        guard let diff = diffResult else {
            // Default coloring if no diff
            guard let document = hexDocument, offset < document.buffer.count else { return (.textColor, .clear) }
            let byte = document.buffer[offset]
            let color = colorCache.count > Int(byte) ? colorCache[Int(byte)] : NSColor.textColor
            return (color, .clear)
        }
        
        // Binary search for block
        // Optimization: Could cache last found block index
        var foundBlock: DiffBlock? = nil
        
        var low = 0
        var high = diff.blocks.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let block = diff.blocks[mid]
            
            if block.range.contains(offset) {
                foundBlock = block
                break
            } else if block.range.lowerBound > offset {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        
        guard let block = foundBlock else {
            // No diff block -> Match (or default)
            guard let document = hexDocument, offset < document.buffer.count else { return (.textColor, .clear) }
            let byte = document.buffer[offset]
            let color = colorCache.count > Int(byte) ? colorCache[Int(byte)] : NSColor.textColor
            return (color, .clear)
        }
        
        switch block.type {
        case .modified:
            return (.white, NSColor.systemRed.withAlphaComponent(0.6))
        case .onlyInFirst:
            return isLeftSide ? (.white, NSColor.systemOrange.withAlphaComponent(0.6)) : (.textColor, .clear)
        case .onlyInSecond:
            return !isLeftSide ? (.white, NSColor.systemGreen.withAlphaComponent(0.6)) : (.textColor, .clear)
        }
    }
    
    private func updateVisibleRows() {
        visibleRows.removeAll()
        guard let document = hexDocument else { return }
        let totalBytes = document.buffer.count
        
        if !showOnlyDifferences {
            updateIntrinsicContentSize()
            return
        }
        
        guard let diff = diffResult, !diff.blocks.isEmpty else {
            // No diffs -> All collapsed
            visibleRows.append(VisibleRow(bufferOffset: 0, isCollapsedRegion: true, collapsedByteCount: totalBytes))
            updateIntrinsicContentSize()
            return
        }
        
        var currentOffset = 0
        
        for block in diff.blocks {
            // Gap before block
            if currentOffset < block.range.lowerBound {
                let gapSize = block.range.lowerBound - currentOffset
                visibleRows.append(VisibleRow(bufferOffset: currentOffset, isCollapsedRegion: true, collapsedByteCount: gapSize))
                currentOffset = block.range.lowerBound
            }
            
            // Block rows
            let blockStart = block.range.lowerBound
            let blockEnd = min(block.range.upperBound, totalBytes - 1)
            let blockSize = blockEnd - blockStart + 1
            let blockRows = (blockSize + bytesPerRow - 1) / bytesPerRow
            
            for i in 0..<blockRows {
                visibleRows.append(VisibleRow(bufferOffset: blockStart + i * bytesPerRow, isCollapsedRegion: false, collapsedByteCount: 0))
            }
            
            currentOffset = blockEnd + 1
        }
        
        // Remaining gap
        if currentOffset < totalBytes {
            let gapSize = totalBytes - currentOffset
            visibleRows.append(VisibleRow(bufferOffset: currentOffset, isCollapsedRegion: true, collapsedByteCount: gapSize))
        }
        
        updateIntrinsicContentSize()
    }
    
    // MARK: - Helper Methods
    
    func yPosition(for offset: Int) -> CGFloat? {
        if showOnlyDifferences {
            // Find row containing offset
            if let index = visibleRows.firstIndex(where: { row in
                if row.isCollapsedRegion {
                    return offset >= row.bufferOffset && offset < row.bufferOffset + row.collapsedByteCount
                } else {
                    return offset >= row.bufferOffset && offset < row.bufferOffset + bytesPerRow
                }
            }) {
                return CGFloat(index) * lineHeight
            }
            return nil
        } else {
            let line = offset / bytesPerRow
            return CGFloat(line) * lineHeight
        }
    }
    
    func offset(at y: CGFloat) -> Int? {
        let line = Int(y / lineHeight)
        if line < 0 { return nil }
        
        if showOnlyDifferences {
            if line < visibleRows.count {
                return visibleRows[line].bufferOffset
            }
            return nil
        } else {
            let offset = line * bytesPerRow
            guard let document = hexDocument, offset < document.buffer.count else { return nil }
            return offset
        }
    }
    
    func flashHighlight(at offset: Int) {
        // Remove existing highlight if any
        highlightLayer?.removeFromSuperlayer()
        highlightLayer = nil
        
        guard let y = yPosition(for: offset) else { return }
        
        // Create new highlight layer
        let layer = CALayer()
        layer.backgroundColor = NSColor.systemYellow.cgColor
        layer.frame = NSRect(x: 10, y: y + 1, width: bounds.width - 20, height: lineHeight - 2)
        layer.cornerRadius = 4.0
        layer.opacity = 0.8
        
        self.layer?.addSublayer(layer)
        self.highlightLayer = layer
        
        // Animate opacity
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.8
        animation.toValue = 0.0
        animation.duration = 0.6
        animation.beginTime = CACurrentMediaTime() + 0.1 // Slight delay
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layer.removeFromSuperlayer()
            if self.highlightLayer === layer {
                self.highlightLayer = nil
            }
        }
        layer.add(animation, forKey: "fadeOut")
        CATransaction.commit()
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
}
