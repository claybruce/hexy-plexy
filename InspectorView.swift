import SwiftUI

struct InspectorView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @State private var isLittleEndian: Bool = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Inspector")
                .font(.headline)
                .padding(.bottom)
            
            Toggle("Little Endian", isOn: $isLittleEndian)
                .padding(.bottom)
            
            if let index = selection.min(), index < document.buffer.count {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Group {
                            Text("Integer")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            inspectorRow(title: "8-bit Signed", value: getValue(at: index, type: Int8.self))
                            inspectorRow(title: "8-bit Unsigned", value: getValue(at: index, type: UInt8.self))
                            
                            Divider()
                            
                            inspectorRow(title: "16-bit Signed", value: getValue(at: index, type: Int16.self))
                            inspectorRow(title: "16-bit Unsigned", value: getValue(at: index, type: UInt16.self))
                            
                            Divider()
                            
                            inspectorRow(title: "32-bit Signed", value: getValue(at: index, type: Int32.self))
                            inspectorRow(title: "32-bit Unsigned", value: getValue(at: index, type: UInt32.self))
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Floating Point")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            inspectorRow(title: "Float", value: getValue(at: index, type: Float32.self))
                            inspectorRow(title: "Double", value: getValue(at: index, type: Float64.self))
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Binary")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            inspectorRow(title: "8-bit Binary", value: getBinaryString(at: index, bits: 8))
                            inspectorRow(title: "16-bit Binary", value: getBinaryString(at: index, bits: 16))
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Decoded Text")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            // Base64
                            if let base64 = tryDecodeBase64(at: index) {
                                inspectorRow(title: "Base64", value: base64)
                            } else {
                                inspectorRow(title: "Base64", value: "Invalid")
                            }
                            
                            // URL
                            if let url = tryDecodeURL(at: index) {
                                inspectorRow(title: "URL Encoded", value: url)
                            } else {
                                inspectorRow(title: "URL Encoded", value: "Invalid")
                            }
                        }
                    }
                }
            } else {
                Text("No selection")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func inspectorRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.monospaced(.body)())
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
    
    // PERFORMANCE: Inline hint for frequently called method
    @inline(__always)
    private func getValue<T: Numeric & CustomStringConvertible>(at index: Int, type: T.Type) -> String {
        let size = MemoryLayout<T>.size
        guard index + size <= document.buffer.count else { return "N/A" }
        
        var bytes: [UInt8] = []
        for i in 0..<size {
            bytes.append(document.buffer[index + i])
        }
        
        // Handle endianness manually since we are constructing from bytes
        if isLittleEndian {
            // Little endian is default for intel/arm, so just load
             return bytes.withUnsafeBytes { $0.load(as: T.self) }.description
        } else {
            // Big endian: reverse bytes then load
            return Array(bytes.reversed()).withUnsafeBytes { $0.load(as: T.self) }.description
        }
    }
    
    // PERFORMANCE: Inline hint for frequently called method
    @inline(__always)
    private func getBinaryString(at index: Int, bits: Int) -> String {
        let byteCount = bits / 8
        guard index + byteCount <= document.buffer.count else { return "N/A" }
        
        var result = ""
        
        // Load bytes
        var bytes: [UInt8] = []
        for i in 0..<byteCount {
            bytes.append(document.buffer[index + i])
        }
        
        // Handle endianness
        if !isLittleEndian {
            bytes.reverse()
        } else {
            // For binary view, we usually want MSB on left, LSB on right.
            // If little endian (LSB first in memory), and we want to show the value as a number:
            // Value: 0x1234
            // LE Memory: 34 12
            // We want to show: 00010010 00110100 (0x12 0x34)
            // So we should actually REVERSE the bytes for display if we are in Little Endian mode
            // to show the "mathematical" value.
            // Wait, standard hex editors usually show memory order for binary?
            // Or value order?
            // Usually value order.
            bytes.reverse()
        }
        
        for byte in bytes {
            let binary = String(byte, radix: 2)
            let padded = String(repeating: "0", count: 8 - binary.count) + binary
            result += padded + " "
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func tryDecodeBase64(at index: Int) -> String? {
        // Try to read a reasonable chunk of bytes and see if it looks like Base64
        let maxLength = 64
        let count = min(maxLength, document.buffer.count - index)
        guard count > 0 else { return nil }
        
        var bytes: [UInt8] = []
        for i in 0..<count {
            let b = document.buffer[index + i]
            // Stop at null terminator or non-printable if we want strictness, 
            // but Base64 chars are specific.
            bytes.append(b)
        }
        
        // Convert to string
        guard let string = String(bytes: bytes, encoding: .utf8) else { return nil }
        
        // Find a valid Base64 substring starting at the beginning
        // This is a bit heuristic. Let's just try to decode the first N chars that look like Base64.
        // Or simpler: Just try to decode the selection if it was a string?
        // The requirement is "decode selected bytes as Base64" -> meaning the bytes ARE the Base64 string?
        // OR "decode the bytes assuming they are a string" -> No, usually it means "Interpret these bytes as a Base64 string and show the decoded data"
        
        // Let's assume the user selected the Base64 string "SGVsbG8="
        // We take those bytes, make a string, and decode it.
        
        // We need to find where the valid Base64 string ends.
        var validLen = 0
        for char in string {
            if char.isLetter || char.isNumber || char == "+" || char == "/" || char == "=" {
                validLen += 1
            } else {
                break
            }
        }
        
        guard validLen >= 4 else { return nil } // Min valid base64 is usually 4 chars
        let candidate = String(string.prefix(validLen))
        
        // Pad if necessary? No, Data(base64Encoded:) is strict.
        // Let's try to decode.
        if let data = Data(base64Encoded: candidate) {
            return String(data: data, encoding: .utf8) ?? data.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
        
        return nil
    }
    
    private func tryDecodeURL(at index: Int) -> String? {
        // Similar logic, try to read string and URL decode it
        let maxLength = 128
        let count = min(maxLength, document.buffer.count - index)
        guard count > 0 else { return nil }
        
        var bytes: [UInt8] = []
        for i in 0..<count {
            bytes.append(document.buffer[index + i])
        }
        
        guard let string = String(bytes: bytes, encoding: .utf8) else { return nil }
        
        // Take until null or newline
        let candidate = string.components(separatedBy: .newlines).first?.components(separatedBy: "\0").first ?? string
        
        return candidate.removingPercentEncoding
    }
}
