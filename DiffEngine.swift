import Foundation

// MARK: - Diff Models

/// Represents a contiguous block of differences
struct DiffBlock: Identifiable, Equatable {
    let id = UUID()
    let range: ClosedRange<Int>
    let type: DiffType
    
    enum DiffType: Equatable {
        case modified      // Bytes differ between files
        case onlyInFirst   // Bytes only in first file
        case onlyInSecond  // Bytes only in second file
    }
    
    var size: Int {
        range.count
    }
}

/// Enhanced diff result with blocks and statistics
struct EnhancedDiffResult {
    let blocks: [DiffBlock]
    let totalDifferences: Int
    let bytesChanged: Int
    let matchPercentage: Double
    let file1Size: Int
    let file2Size: Int
    
    var hasDifferences: Bool {
        !blocks.isEmpty
    }
    
    /// Get the index of the block containing the given byte offset
    func blockIndex(containing offset: Int) -> Int? {
        blocks.firstIndex { $0.range.contains(offset) }
    }
}

// MARK: - Rabin-Karp Rolling Hash Implementation

/// Rolling hash implementation using Rabin-Karp algorithm for efficient windowed hashing
struct RollingHash {
    static let BASE: UInt64 = 256
    static let MOD: UInt64 = 1_000_000_007 // Large prime
    static let WINDOW_SIZE = 64 // 64-byte windows

    private var hash: UInt64 = 0
    private var basePower: UInt64 = 1
    private var window: [UInt8] = []
    private var isInitialized = false

    mutating func initialize(with data: GapBuffer, start: Int) {
        guard start + RollingHash.WINDOW_SIZE <= data.count else { return }

        hash = 0
        basePower = 1
        window = []

        for i in 0..<RollingHash.WINDOW_SIZE {
            let byte = data[start + i]
            window.append(byte)
            hash = (hash * RollingHash.BASE + UInt64(byte)) % RollingHash.MOD
            if i > 0 {
                basePower = (basePower * RollingHash.BASE) % RollingHash.MOD
            }
        }

        isInitialized = true
    }

    mutating func roll(with newByte: UInt8) -> UInt64 {
        guard isInitialized else { return 0 }

        // Remove the oldest byte
        let oldestByte = window.removeFirst()
        hash = (hash + RollingHash.MOD - (UInt64(oldestByte) * basePower) % RollingHash.MOD) % RollingHash.MOD

        // Add the new byte
        window.append(newByte)
        hash = (hash * RollingHash.BASE + UInt64(newByte)) % RollingHash.MOD

        return hash
    }

    func currentHash() -> UInt64 {
        hash
    }

    static func computeHashes(for buffer: GapBuffer) async -> [Int: UInt64] {
        var hashes: [Int: UInt64] = [:]
        var rollingHash = RollingHash()

        let count = buffer.count
        guard count >= WINDOW_SIZE else { return hashes }

        // Initialize first window
        rollingHash.initialize(with: buffer, start: 0)
        hashes[0] = rollingHash.currentHash()

        // Roll through the rest
        for offset in 1..<(count - WINDOW_SIZE + 1) {
            if offset % 10000 == 0 { await Task.yield() }

            let newByte = buffer[offset + WINDOW_SIZE - 1]
            let hash = rollingHash.roll(with: newByte)
            hashes[offset] = hash
        }

        return hashes
    }
}

// MARK: - xxHash64 Implementation

/// Fast non-cryptographic hash function optimized for speed
struct xxHash64 {
    private static let PRIME64_1: UInt64 = 0x9E3779B185EBCA87
    private static let PRIME64_2: UInt64 = 0xC2B2AE3D27D4EB4F
    private static let PRIME64_3: UInt64 = 0x165667B19E3779F9
    private static let PRIME64_4: UInt64 = 0x85EBCA77C2B2AE63
    private static let PRIME64_5: UInt64 = 0x27D4EB2F165667C5
    
    static func hash(_ data: Data, seed: UInt64 = 0) -> UInt64 {
        var h64: UInt64
        let len = data.count
        
        if len >= 32 {
            var v1 = seed &+ PRIME64_1 &+ PRIME64_2
            var v2 = seed &+ PRIME64_2
            var v3 = seed
            var v4 = seed &- PRIME64_1
            
            let limit = len - 32
            var offset = 0
            
            repeat {
                v1 = round(v1, data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) })
                offset += 8
                v2 = round(v2, data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) })
                offset += 8
                v3 = round(v3, data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) })
                offset += 8
                v4 = round(v4, data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) })
                offset += 8
            } while offset <= limit
            
            h64 = rotateLeft(v1, by: 1) &+ rotateLeft(v2, by: 7) &+ rotateLeft(v3, by: 12) &+ rotateLeft(v4, by: 18)
            h64 = mergeRound(h64, v1)
            h64 = mergeRound(h64, v2)
            h64 = mergeRound(h64, v3)
            h64 = mergeRound(h64, v4)
        } else {
            h64 = seed &+ PRIME64_5
        }
        
        h64 &+= UInt64(len)
        
        let remaining = len & 31
        var offset = len - remaining
        
        while offset + 8 <= len {
            let k1 = round(0, data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self) })
            h64 ^= k1
            h64 = rotateLeft(h64, by: 27) &* PRIME64_1 &+ PRIME64_4
            offset += 8
        }
        
        if offset + 4 <= len {
            h64 ^= UInt64(data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }) &* PRIME64_1
            h64 = rotateLeft(h64, by: 23) &* PRIME64_2 &+ PRIME64_3
            offset += 4
        }
        
        while offset < len {
            h64 ^= UInt64(data[offset]) &* PRIME64_5
            h64 = rotateLeft(h64, by: 11) &* PRIME64_1
            offset += 1
        }
        
        h64 ^= h64 >> 33
        h64 &*= PRIME64_2
        h64 ^= h64 >> 29
        h64 &*= PRIME64_3
        h64 ^= h64 >> 32
        
        return h64
    }
    
    private static func round(_ acc: UInt64, _ input: UInt64) -> UInt64 {
        var acc = acc
        acc &+= input &* PRIME64_2
        acc = rotateLeft(acc, by: 31)
        acc &*= PRIME64_1
        return acc
    }
    
    private static func mergeRound(_ acc: UInt64, _ val: UInt64) -> UInt64 {
        var acc = acc
        let val = round(0, val)
        acc ^= val
        acc = acc &* PRIME64_1 &+ PRIME64_4
        return acc
    }
    
    private static func rotateLeft(_ value: UInt64, by amount: UInt64) -> UInt64 {
        return (value << amount) | (value >> (64 - amount))
    }
}

// MARK: - Diff Engine

class DiffEngine {
    private static let CHUNK_SIZE = 65536 // 64KB chunks
    
    /// Compare two buffers and return enhanced diff results with blocks
    static func compare(buffer1: GapBuffer, buffer2: GapBuffer) async -> EnhancedDiffResult {
        await Task.yield()

        let count1 = buffer1.count
        let count2 = buffer2.count

        // Quick check: if sizes differ significantly, skip hash check
        if count1 == count2 {
            // Fast path: Check if files are identical using hash
            let hash1 = await computeHash(buffer: buffer1)
            let hash2 = await computeHash(buffer: buffer2)

            if hash1 == hash2 {
                // Files are identical
                return EnhancedDiffResult(
                    blocks: [],
                    totalDifferences: 0,
                    bytesChanged: 0,
                    matchPercentage: 100.0,
                    file1Size: count1,
                    file2Size: count2
                )
            }
        }

        // Use rolling hash-based diffing
        let result = await rollingHashDiff(buffer1: buffer1, buffer2: buffer2)
        return result
    }
    
    // MARK: - Hash Computation
    
    private static func computeHash(buffer: GapBuffer) async -> UInt64 {
        let chunkSize = 65536
        var hash: UInt64 = 0
        
        for offset in stride(from: 0, to: buffer.count, by: chunkSize) {
            if offset % (chunkSize * 10) == 0 {
                await Task.yield()
            }
            
            let end = min(offset + chunkSize, buffer.count)
            let data = Data((offset..<end).map { buffer[$0] })
            hash ^= xxHash64.hash(data, seed: UInt64(offset))
        }
        
        return hash
    }
    
    // MARK: - Rolling Hash Diff Strategy

    private static func rollingHashDiff(buffer1: GapBuffer, buffer2: GapBuffer) async -> EnhancedDiffResult {
        let count1 = buffer1.count
        let count2 = buffer2.count

        // Compute rolling hashes for both buffers
        let hashes1 = await RollingHash.computeHashes(for: buffer1)
        let hashes2 = await RollingHash.computeHashes(for: buffer2)

        // Find matching blocks using rolling hashes
        let matchingBlocks = await findMatchingBlocks(hashes1: hashes1, hashes2: hashes2, buffer1: buffer1, buffer2: buffer2)

        // Process the matching blocks and identify differences
        var allBlocks: [DiffBlock] = []
        var totalMatches = 0
        var totalDiffs = 0

        // Sort matching blocks by start position in buffer1
        let sortedBlocks = matchingBlocks.sorted { $0.range1.lowerBound < $1.range1.lowerBound }

        var lastEnd1 = 0
        var lastEnd2 = 0

        for block in sortedBlocks {
            await Task.yield()

            // Skip blocks that overlap with already processed regions
            if block.range1.lowerBound < lastEnd1 || block.range2.lowerBound < lastEnd2 {
                continue
            }

            // Handle region before this matching block
            let diffRange1 = lastEnd1..<block.range1.lowerBound
            let diffRange2 = lastEnd2..<block.range2.lowerBound

            if !diffRange1.isEmpty || !diffRange2.isEmpty {
                let (blocks, matches, diffs) = await simpleByteCompare(
                    buffer1: buffer1,
                    range1: diffRange1,
                    buffer2: buffer2,
                    range2: diffRange2
                )
                allBlocks.append(contentsOf: blocks)
                totalMatches += matches
                totalDiffs += diffs
            }

            // Add the matching block
            totalMatches += block.range1.count

            lastEnd1 = max(lastEnd1, block.range1.upperBound)
            lastEnd2 = max(lastEnd2, block.range2.upperBound)
        }

        // Handle remaining regions
        if lastEnd1 < count1 || lastEnd2 < count2 {
            let diffRange1 = lastEnd1..<count1
            let diffRange2 = lastEnd2..<count2

            let (blocks, matches, diffs) = await simpleByteCompare(
                buffer1: buffer1,
                range1: diffRange1,
                buffer2: buffer2,
                range2: diffRange2
            )
            allBlocks.append(contentsOf: blocks)
            totalMatches += matches
            totalDiffs += diffs
        }

        // Merge adjacent blocks of the same type
        let mergedBlocks = mergeAdjacentBlocks(allBlocks)

        let largerSize = max(count1, count2)
        let matchPercentage = largerSize > 0 ? Double(totalMatches) / Double(largerSize) * 100.0 : 100.0

        return EnhancedDiffResult(
            blocks: mergedBlocks,
            totalDifferences: totalDiffs,
            bytesChanged: totalDiffs,
            matchPercentage: matchPercentage,
            file1Size: count1,
            file2Size: count2
        )
    }
    
    private struct MatchingBlock {
        let range1: Range<Int>
        let range2: Range<Int>
    }

    private static func findMatchingBlocks(hashes1: [Int: UInt64], hashes2: [Int: UInt64], buffer1: GapBuffer, buffer2: GapBuffer) async -> [MatchingBlock] {
        // Create hash to positions map for buffer2
        var hashToPositions2: [UInt64: [Int]] = [:]
        for (pos, hash) in hashes2 {
            hashToPositions2[hash, default: []].append(pos)
        }

        var matchingBlocks: [MatchingBlock] = []
        var usedPositions1 = Set<Int>()
        var usedPositions2 = Set<Int>()

        // Sort positions by hash frequency (prefer common hashes)
        let sortedPositions1 = hashes1.keys.sorted { pos1, pos2 in
            let hash1 = hashes1[pos1]!
            let hash2 = hashes1[pos2]!
            let freq1 = hashToPositions2[hash1]?.count ?? 0
            let freq2 = hashToPositions2[hash2]?.count ?? 0
            return freq1 > freq2
        }

        for pos1 in sortedPositions1 {
            if usedPositions1.contains(pos1) { continue }

            let hash = hashes1[pos1]!
            guard let positions2 = hashToPositions2[hash] else { continue }

            for pos2 in positions2 {
                if usedPositions2.contains(pos2) { continue }

                // Verify the match by checking actual bytes
                if await verifyMatch(buffer1: buffer1, pos1: pos1, buffer2: buffer2, pos2: pos2) {
                    // Extend the match to find the full matching region
                    let block = await extendMatch(buffer1: buffer1, start1: pos1, buffer2: buffer2, start2: pos2, used1: &usedPositions1, used2: &usedPositions2)
                    if block.range1.count >= RollingHash.WINDOW_SIZE {
                        matchingBlocks.append(block)
                    }
                    break // Found a match for this position
                }
            }
        }

        return matchingBlocks
    }

    private static func verifyMatch(buffer1: GapBuffer, pos1: Int, buffer2: GapBuffer, pos2: Int) async -> Bool {
        let windowSize = RollingHash.WINDOW_SIZE
        for i in 0..<windowSize {
            if buffer1[pos1 + i] != buffer2[pos2 + i] {
                return false
            }
        }
        return true
    }

    private static func extendMatch(buffer1: GapBuffer, start1: Int, buffer2: GapBuffer, start2: Int, used1: inout Set<Int>, used2: inout Set<Int>) async -> MatchingBlock {
        let windowSize = RollingHash.WINDOW_SIZE

        // Extend backwards
        var backExtend = 0
        while start1 - backExtend > 0 && start2 - backExtend > 0 &&
              buffer1[start1 - backExtend - 1] == buffer2[start2 - backExtend - 1] &&
              !used1.contains(start1 - backExtend - 1) &&
              !used2.contains(start2 - backExtend - 1) {
            backExtend += 1
            if backExtend % 1000 == 0 { await Task.yield() }
        }

        // Extend forwards
        var forwardExtend = windowSize
        while start1 + forwardExtend < buffer1.count && start2 + forwardExtend < buffer2.count &&
              buffer1[start1 + forwardExtend] == buffer2[start2 + forwardExtend] &&
              !used1.contains(start1 + forwardExtend) &&
              !used2.contains(start2 + forwardExtend) {
            forwardExtend += 1
            if forwardExtend % 1000 == 0 { await Task.yield() }
        }

        let range1 = (start1 - backExtend)..<(start1 + forwardExtend)
        let range2 = (start2 - backExtend)..<(start2 + forwardExtend)

        // Mark positions as used
        for i in range1 {
            used1.insert(i)
        }
        for i in range2 {
            used2.insert(i)
        }

        return MatchingBlock(range1: range1, range2: range2)
    }
    
    private static func simpleByteCompare(
        buffer1: GapBuffer,
        range1: Range<Int>,
        buffer2: GapBuffer,
        range2: Range<Int>
    ) async -> (blocks: [DiffBlock], matches: Int, diffs: Int) {
        var blocks: [DiffBlock] = []
        var matches = 0
        var diffs = 0
        
        let count1 = range1.count
        let count2 = range2.count
        let minCount = min(count1, count2)
        
        // Compare common bytes
        var currentDiffStart: Int? = nil
        
        for i in 0..<minCount {
            if i % 10000 == 0 { await Task.yield() }
            
            let offset1 = range1.lowerBound + i
            let offset2 = range2.lowerBound + i
            
            if buffer1[offset1] == buffer2[offset2] {
                // Match found
                if let diffStart = currentDiffStart {
                    // Close current diff block
                    blocks.append(DiffBlock(
                        range: diffStart...offset1 - 1,
                        type: .modified
                    ))
                    currentDiffStart = nil
                }
                matches += 1
            } else {
                // Difference found
                if currentDiffStart == nil {
                    currentDiffStart = offset1
                }
                diffs += 1
            }
        }
        
        // Close any remaining diff block
        if let diffStart = currentDiffStart {
            blocks.append(DiffBlock(
                range: diffStart...(range1.lowerBound + minCount - 1),
                type: .modified
            ))
        }
        
        // Handle size differences
        if count1 > minCount {
            blocks.append(DiffBlock(
                range: (range1.lowerBound + minCount)...(range1.upperBound - 1),
                type: .onlyInFirst
            ))
            diffs += count1 - minCount
        } else if count2 > minCount {
            blocks.append(DiffBlock(
                range: (range2.lowerBound + minCount)...(range2.upperBound - 1),
                type: .onlyInSecond
            ))
            diffs += count2 - minCount
        }
        
        return (blocks, matches, diffs)
    }
    
    private static func mergeAdjacentBlocks(_ blocks: [DiffBlock]) -> [DiffBlock] {
        guard !blocks.isEmpty else { return [] }
        
        var merged: [DiffBlock] = []
        var current = blocks[0]
        
        for i in 1..<blocks.count {
            let next = blocks[i]
            
            // Check if blocks are adjacent and same type
            if current.type == next.type && current.range.upperBound + 1 == next.range.lowerBound {
                // Merge blocks
                current = DiffBlock(
                    range: current.range.lowerBound...next.range.upperBound,
                    type: current.type
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        
        merged.append(current)
        return merged
    }

}
