import SwiftUI

struct InsertDataView: View {
    @ObservedObject var document: HexDocument
    @Binding var insertPosition: Int
    @Binding var isPresented: Bool
    @Environment(\.undoManager) var undoManager
    
    @State private var inputText: String = ""
    @State private var inputMode: InputMode = .ascii
    
    enum InputMode: String, CaseIterable {
        case ascii = "ASCII"
        case hex = "Hex"
        case utf8 = "UTF-8"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Insert Data")
                .font(.title2.bold())
            
            // Input mode picker
            Picker("Input Mode", selection: $inputMode) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text(inputModeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $inputText)
                    .font(.monospaced(.body)())
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3), width: 1)
            }
            .frame(width: 400)
            
            // Preview
            if !inputText.isEmpty, let bytes = convertToBytes() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview: \(bytes.count) byte(s)")
                        .font(.caption.bold())
                    Text(bytes.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    if bytes.count > 16 {
                        Text("... and \(bytes.count - 16) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Insert") {
                    performInsert()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(inputText.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private var inputModeDescription: String {
        switch inputMode {
        case .ascii:
            return "Enter ASCII text to insert"
        case .hex:
            return "Enter hex bytes (e.g., FF 00 A1 or FF00A1)"
        case .utf8:
            return "Enter UTF-8 text to insert"
        }
    }
    
    private func convertToBytes() -> [UInt8]? {
        switch inputMode {
        case .ascii:
            // ASCII - only characters 0-127
            return inputText.compactMap { char in
                guard char.isASCII else { return nil }
                return UInt8(char.asciiValue!)
            }
            
        case .hex:
            // Hex - parse hex string
            let cleaned = inputText.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: "")
            return HexInputHelper.hexStringToBytes(cleaned)
            
        case .utf8:
            // UTF-8 - encode as UTF-8 bytes
            return [UInt8](inputText.utf8)
        }
    }
    
    private func performInsert() {
        guard let bytes = convertToBytes(), !bytes.isEmpty else { return }
        
        document.insert(bytes: bytes, at: insertPosition, undoManager: undoManager)
        
        isPresented = false
    }
}
