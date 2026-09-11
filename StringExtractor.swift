import Foundation

struct FoundString: Identifiable, Equatable, Hashable {
    let id = UUID()
    let offset: Int
    let value: String
    let length: Int
    let type: StringType
    
    enum StringType: String {
        case ascii = "ASCII"
        case unicode = "Unicode" // UTF-16 LE
    }
}

class StringExtractor {
    static func extractStrings(from buffer: GapBuffer, minLength: Int = 4) async -> [FoundString] {
        var results: [FoundString] = []
        
        // We need to access the buffer safely. 
        // Since DataBuffer is likely a GapBuffer or similar, let's assume we can iterate it or convert to Data.
        // For performance on large files, we should iterate directly if possible.
        // But for now, let's copy to [UInt8] for easier processing in background.
        
        let bytes = Array(buffer) // This might be expensive for huge files, but okay for MVP
        
        // Search for ASCII strings
        var currentStringBytes: [UInt8] = []
        var currentStart = -1
        
        for (index, byte) in bytes.enumerated() {
            // Printable ASCII range: 32-126, plus tab (9)
            if (byte >= 32 && byte <= 126) || byte == 9 {
                if currentStart == -1 {
                    currentStart = index
                }
                currentStringBytes.append(byte)
            } else {
                if currentStringBytes.count >= minLength {
                    if let str = String(bytes: currentStringBytes, encoding: .ascii) {
                        results.append(FoundString(offset: currentStart, value: str, length: currentStringBytes.count, type: .ascii))
                    }
                }
                currentStringBytes = []
                currentStart = -1
            }
        }
        // Check end of file
        if currentStringBytes.count >= minLength {
            if let str = String(bytes: currentStringBytes, encoding: .ascii) {
                results.append(FoundString(offset: currentStart, value: str, length: currentStringBytes.count, type: .ascii))
            }
        }
        
        // Search for Unicode (UTF-16 LE) strings
        // Basic heuristic: sequence of (char, 0x00) pairs
        // This is a simplification but works for many English/European Windows strings
        
        var currentUnicodeBytes: [UInt8] = []
        var unicodeStart = -1
        
        // We step by 2
        var i = 0
        while i < bytes.count - 1 {
            let b1 = bytes[i]
            let b2 = bytes[i+1]
            
            // Check for Basic Latin in UTF-16LE: (char, 0x00)
            if (b1 >= 32 && b1 <= 126) && b2 == 0 {
                if unicodeStart == -1 {
                    unicodeStart = i
                }
                currentUnicodeBytes.append(b1)
                currentUnicodeBytes.append(b2)
                i += 2
            } else {
                if currentUnicodeBytes.count >= minLength * 2 {
                    // Try to decode
                    let data = Data(currentUnicodeBytes)
                    if let str = String(data: data, encoding: .utf16LittleEndian) {
                         results.append(FoundString(offset: unicodeStart, value: str, length: currentUnicodeBytes.count, type: .unicode))
                    }
                }
                currentUnicodeBytes = []
                unicodeStart = -1
                i += 1 // Advance 1 to check next alignment
            }
        }
        
        return results.sorted { $0.offset < $1.offset }
    }
}
