import Foundation

/// A Gap Buffer implementation for efficient editing of data.
/// It maintains a "gap" in the storage to allow for O(1) insertions and deletions at the cursor position.
/// OPTIMIZED: Added inline hints and batch access methods for performance
struct GapBuffer: RandomAccessCollection {
    typealias Index = Int
    typealias Element = UInt8
    
    private var buffer: [UInt8]
    private var gapStart: Int
    private var gapEnd: Int
    
    init(data: Data = Data()) {
        self.buffer = [UInt8](data)
        self.gapStart = buffer.count
        self.gapEnd = buffer.count
    }
    
    var startIndex: Int { 0 }
    var endIndex: Int { buffer.count - (gapEnd - gapStart) }
    
    /// The total number of bytes in the buffer (excluding the gap).
    var count: Int {
        return endIndex
    }
    
    /// Accesses the byte at the given index.
    /// PERFORMANCE: Inlined for faster repeated access
    @inline(__always)
    subscript(index: Int) -> UInt8 {
        get {
            let physicalIndex = index < gapStart ? index : index + (gapEnd - gapStart)
            return buffer[physicalIndex]
        }
        set {
            let physicalIndex = index < gapStart ? index : index + (gapEnd - gapStart)
            buffer[physicalIndex] = newValue
        }
    }
    
    /// PERFORMANCE: Batch access method for efficient row extraction
    /// Reduces function call overhead when reading multiple consecutive bytes
    @inline(__always)
    func getBytes(in range: Range<Int>) -> [UInt8] {
        let start = range.lowerBound
        let end = range.upperBound
        let count = end - start
        
        if count <= 0 { return [] }
        
        // Case 1: Range is entirely before the gap
        if end <= gapStart {
            return Array(buffer[start..<end])
        }
        
        // Case 2: Range is entirely after the gap
        if start >= gapStart {
            let physicalStart = start + (gapEnd - gapStart)
            let physicalEnd = end + (gapEnd - gapStart)
            
            // Ensure we don't exceed buffer bounds
            let safePhysicalEnd = Swift.min(physicalEnd, buffer.count)
            if physicalStart < safePhysicalEnd {
                return Array(buffer[physicalStart..<safePhysicalEnd])
            }
            return []
        }
        
        // Case 3: Range spans the gap
        var result = [UInt8]()
        result.reserveCapacity(count)
        
        // Part before gap
        result.append(contentsOf: buffer[start..<gapStart])
        
        // Part after gap
        let physicalGapEnd = gapEnd
        let remaining = end - gapStart
        let physicalEnd = Swift.min(physicalGapEnd + remaining, buffer.count)
        
        // Ensure we don't go beyond buffer bounds
        if physicalGapEnd < physicalEnd {
            result.append(contentsOf: buffer[physicalGapEnd..<physicalEnd])
        }
        
        return result
    }
    
    /// Moves the gap to the specified index.
    mutating func moveGap(to index: Int) {
        // Clamp index to valid bounds
        let safeIndex = Swift.max(0, Swift.min(index, buffer.count))
        if safeIndex == gapStart { return }
        
        let gapSize = gapEnd - gapStart
        
        if safeIndex < gapStart {
            // Move gap left
            buffer.replaceSubrange(safeIndex + gapSize..<gapStart + gapSize, with: buffer[safeIndex..<gapStart])
            gapStart = safeIndex
            gapEnd = gapStart + gapSize
        } else {
            // Move gap right
            let moveCount = safeIndex - gapStart
            
            // Ensure we don't exceed buffer bounds
            let availableBytes = buffer.count - gapEnd
            let safeMoveCount = Swift.min(moveCount, availableBytes)
            
            if safeMoveCount > 0 {
                buffer.replaceSubrange(gapStart..<gapStart + safeMoveCount, with: buffer[gapEnd..<gapEnd + safeMoveCount])
                gapStart += safeMoveCount
                gapEnd += safeMoveCount
            }
        }
    }
    
    /// Inserts a byte at the current gap position.
    mutating func insert(_ byte: UInt8, at index: Int) {
        moveGap(to: index)
        
        if gapStart == gapEnd {
            expandGap()
        }
        
        buffer[gapStart] = byte
        gapStart += 1
    }
    
    /// Inserts a sequence of bytes at the current gap position.
    mutating func insert<S: Sequence>(_ bytes: S, at index: Int) where S.Element == UInt8 {
        moveGap(to: index)
        
        for byte in bytes {
            if gapStart == gapEnd {
                expandGap()
            }
            buffer[gapStart] = byte
            gapStart += 1
        }
    }
    
    /// Deletes a byte at the specified index.
    mutating func delete(at index: Int) {
        if index < 0 || index >= count { return }
        moveGap(to: index + 1)
        if gapStart > 0 {
            gapStart -= 1
        }
    }
    
    /// Deletes a range of bytes.
    mutating func delete(in range: Range<Int>) {
        let safeStart = Swift.max(0, range.lowerBound)
        let safeEnd = Swift.min(range.upperBound, count)
        if safeStart >= safeEnd { return }
        
        moveGap(to: safeEnd)
        gapStart -= (safeEnd - safeStart)
    }
    
    /// Expands the gap when it's full.
    private mutating func expandGap() {
        let newCapacity = Swift.max(buffer.count * 2, 64)
        let gapSize = newCapacity - buffer.count
        
        // Insert gap at current gapEnd
        // Actually, since we are using Array, we can just insert uninitialized space or zeros
        // But Array doesn't support uninitialized insert easily without unsafe.
        // For simplicity in Swift, we'll just insert zeros.
        // Optimization: Use UnsafeMutableBufferPointer for better performance later.
        let zeros = [UInt8](repeating: 0, count: gapSize)
        buffer.insert(contentsOf: zeros, at: gapEnd)
        gapEnd += gapSize
    }
    
    /// Returns the data as a contiguous Data object.
    /// PERFORMANCE: Uses pre-allocated capacity
    func toData() -> Data {
        var data = Data()
        data.reserveCapacity(count)
        data.append(contentsOf: buffer[0..<gapStart])
        data.append(contentsOf: buffer[gapEnd..<buffer.count])
        return data
    }
}
