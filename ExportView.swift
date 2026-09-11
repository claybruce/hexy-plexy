//
//  ExportView.swift
//  HxEditor
//
//  Export data in various formats
//

import SwiftUI
import AppKit

struct ExportView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    
    @State private var selectedFormat: ExportFormat = .cArray
    @State private var preview: String = ""
    @State private var isGenerating = false
    
    // C Array options
    @State private var variableName: String = "data"
    @State private var bytesPerLine: Int = 16
    @State private var includeLength: Bool = true
    
    // Hex dump options
    @State private var showASCII: Bool = true
    @State private var showOffsets: Bool = true
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case cArray = "C Array"
        case base64 = "Base64"
        case hexDump = "Hex Dump"
        case binary = "Binary"
        case intelHex = "Intel HEX"
        case motorolaS = "Motorola S-Record"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .cArray: return "curlybraces"
            case .base64: return "textformat.abc"
            case .hexDump: return "list.bullet.rectangle"
            case .binary: return "0.circle"
            case .intelHex: return "cpu"
            case .motorolaS: return "memorychip"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .cArray: return "c"
            case .base64: return "txt"
            case .hexDump: return "txt"
            case .binary: return "bin"
            case .intelHex: return "hex"
            case .motorolaS: return "s19"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Data")
                    .font(.title2.bold())
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            
            Divider()
            
            HStack(spacing: 0) {
                // Left panel - Options
                VStack(alignment: .leading, spacing: 16) {
                    // Selection info
                    GroupBox(label: Label("Export Selection", systemImage: "selection.pin.in.out")) {
                        if selection.isEmpty {
                            Text("No bytes selected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("\(selection.count) bytes selected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Format selection
                    GroupBox(label: Label("Format", systemImage: "doc.text")) {
                        VStack(spacing: 8) {
                            ForEach(ExportFormat.allCases) { format in
                                Button(action: { selectedFormat = format }) {
                                    HStack {
                                        Image(systemName: format.icon)
                                            .frame(width: 20)
                                        Text(format.rawValue)
                                        Spacer()
                                        if selectedFormat == format {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(selectedFormat == format ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Format-specific options
                    if selectedFormat == .cArray {
                        GroupBox(label: Label("C Array Options", systemImage: "gearshape")) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Variable Name", text: $variableName)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Text("Bytes per line:")
                                        .font(.caption)
                                    Stepper("\(bytesPerLine)", value: $bytesPerLine, in: 1...32)
                                        .font(.caption)
                                }
                                
                                Toggle("Include length constant", isOn: $includeLength)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if selectedFormat == .hexDump {
                        GroupBox(label: Label("Hex Dump Options", systemImage: "gearshape")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Show offsets", isOn: $showOffsets)
                                    .font(.caption)
                                Toggle("Show ASCII", isOn: $showASCII)
                                    .font(.caption)
                                
                                HStack {
                                    Text("Bytes per line:")
                                        .font(.caption)
                                    Stepper("\(bytesPerLine)", value: $bytesPerLine, in: 8...32)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 8) {
                        Button(action: copyToClipboard) {
                            Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(preview.isEmpty || isGenerating)
                        
                        Button(action: saveToFile) {
                            Label("Save to File", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(preview.isEmpty || isGenerating)
                    }
                    .padding()
                }
                .frame(width: 300)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Right panel - Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        Spacer()
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding()
                    
                    ScrollView {
                        Text(preview.isEmpty ? "Select a format to generate preview" : preview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom])
                }
            }
        }
        .frame(width: 800, height: 600)
        .onChange(of: selectedFormat) { _, _ in generatePreview() }
        .onChange(of: variableName) { _, _ in if selectedFormat == .cArray { generatePreview() } }
        .onChange(of: bytesPerLine) { _, _ in if selectedFormat == .cArray || selectedFormat == .hexDump { generatePreview() } }
        .onChange(of: includeLength) { _, _ in if selectedFormat == .cArray { generatePreview() } }
        .onChange(of: showOffsets) { _, _ in if selectedFormat == .hexDump { generatePreview() } }
        .onChange(of: showASCII) { _, _ in if selectedFormat == .hexDump { generatePreview() } }
        .onAppear {
            generatePreview()
        }
    }
    
    private func getExportData() -> [UInt8] {
        let validIndices = selection.sorted().filter { $0 >= 0 && $0 < document.buffer.count }
        return validIndices.map { document.buffer[$0] }
    }
    
    private func generatePreview() {
        isGenerating = true
        preview = ""
        
        Task {
            let data = getExportData()
            let result = await generateExport(data: data, format: selectedFormat)
            
            await MainActor.run {
                preview = result
                isGenerating = false
            }
        }
    }
    
    private func generateExport(data: [UInt8], format: ExportFormat) async -> String {
        switch format {
        case .cArray:
            return generateCArray(data: data)
        case .base64:
            return Data(data).base64EncodedString()
        case .hexDump:
            return generateHexDump(data: data)
        case .binary:
            return "Binary data (\(data.count) bytes)\nUse 'Save to File' to export."
        case .intelHex:
            return generateIntelHex(data: data)
        case .motorolaS:
            return generateMotorolaS(data: data)
        }
    }
    
    private func generateCArray(data: [UInt8]) -> String {
        var result = "// Generated by HxEditor\n"
        
        if includeLength {
            result += "const unsigned int \(variableName)_len = \(data.count);\n"
        }
        
        result += "const unsigned char \(variableName)[] = {\n"
        
        for (index, byte) in data.enumerated() {
            if index % bytesPerLine == 0 {
                result += "    "
            }
            
            result += String(format: "0x%02X", byte)
            
            if index < data.count - 1 {
                result += ","
                if (index + 1) % bytesPerLine == 0 {
                    result += "\n"
                } else {
                    result += " "
                }
            }
        }
        
        result += "\n};\n"
        return result
    }
    
    private func generateHexDump(data: [UInt8]) -> String {
        var result = ""
        let lineCount = (data.count + bytesPerLine - 1) / bytesPerLine
        
        for line in 0..<lineCount {
            let offset = line * bytesPerLine
            let end = min(offset + bytesPerLine, data.count)
            let lineData = Array(data[offset..<end])
            
            // Offset
            if showOffsets {
                result += String(format: "%08X  ", offset)
            }
            
            // Hex bytes
            for (i, byte) in lineData.enumerated() {
                result += String(format: "%02X ", byte)
                if bytesPerLine == 16 && i == 7 {
                    result += " "
                }
            }
            
            // Padding
            let padding = bytesPerLine - lineData.count
            result += String(repeating: "   ", count: padding)
            if bytesPerLine == 16 && lineData.count <= 8 {
                result += " "
            }
            
            // ASCII
            if showASCII {
                result += " |"
                for byte in lineData {
                    if byte >= 32 && byte <= 126 {
                        result += String(Character(UnicodeScalar(byte)))
                    } else {
                        result += "."
                    }
                }
                result += "|"
            }
            
            result += "\n"
        }
        
        return result
    }
    
    private func generateIntelHex(data: [UInt8]) -> String {
        var result = ""
        let lineLen = 16
        let lineCount = (data.count + lineLen - 1) / lineLen
        
        for line in 0..<lineCount {
            let offset = line * lineLen
            let end = min(offset + lineLen, data.count)
            let lineData = Array(data[offset..<end])
            let byteCount = lineData.count
            
            // Record format: :LLAAAATT[DD...]CC
            // LL = byte count, AAAA = address, TT = record type (00 = data)
            var checksum = UInt8(byteCount)
            checksum = checksum &+ UInt8((offset >> 8) & 0xFF)
            checksum = checksum &+ UInt8(offset & 0xFF)
            checksum = checksum &+ 0x00 // Record type
            
            var record = String(format: ":%02X%04X00", byteCount, offset)
            
            for byte in lineData {
                record += String(format: "%02X", byte)
                checksum = checksum &+ byte
            }
            
            checksum = (~checksum &+ 1) // Two's complement
            record += String(format: "%02X\n", checksum)
            
            result += record
        }
        
        // End of file record
        result += ":00000001FF\n"
        
        return result
    }
    
    private func generateMotorolaS(data: [UInt8]) -> String {
        var result = ""
        let lineLen = 16
        let lineCount = (data.count + lineLen - 1) / lineLen
        
        for line in 0..<lineCount {
            let offset = line * lineLen
            let end = min(offset + lineLen, data.count)
            let lineData = Array(data[offset..<end])
            let byteCount = lineData.count + 3 // +3 for address and checksum
            
            // S1 record: S1LLAAAAD...CC
            var checksum = UInt8(byteCount)
            checksum = checksum &+ UInt8((offset >> 8) & 0xFF)
            checksum = checksum &+ UInt8(offset & 0xFF)
            
            var record = String(format: "S1%02X%04X", byteCount, offset)
            
            for byte in lineData {
                record += String(format: "%02X", byte)
                checksum = checksum &+ byte
            }
            
            checksum = ~checksum
            record += String(format: "%02X\n", checksum)
            
            result += record
        }
        
        // S9 termination record
        result += "S9030000FC\n"
        
        return result
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(preview, forType: .string)
    }
    
    @State private var showFileExporter = false
    
    private func saveToFile() {
        showFileExporter = true
    }
}
