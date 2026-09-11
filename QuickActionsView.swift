//
//  QuickActionsView.swift
//  HxEditor
//
//  Quick actions panel for common operations
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickActionsView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    var undoManager: UndoManager?
    
    @State private var fillByte: String = "00"
    @State private var patternType: PatternType = .incremental
    @State private var startValue: String = "00"
    @State private var showExportPanel = false
    @State private var showDuplicateAlert = false
    @State private var showFileExporter = false
    
    // Helper for file export
    @State private var duplicateFilename: String = "Untitled.duplicated"
    
    enum PatternType: String, CaseIterable {
        case incremental = "Incremental"
        case random = "Random"
        case custom = "Custom Pattern"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Quick Actions")
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
            .padding(.horizontal)
            
            if selection.isEmpty {
                Text("Select bytes to perform actions")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Fill action
                        GroupBox(label: Label("Fill Selection", systemImage: "paintbrush.fill")) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField("Byte (hex)", text: $fillByte)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    
                                    Button("Fill") {
                                        performFill()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                Text("Fill \(selection.count) bytes with 0x\(fillByte)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                        }
                        
                        // Pattern generation
                        GroupBox(label: Label("Generate Pattern", systemImage: "chart.bar.fill")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Pattern", selection: $patternType) {
                                    ForEach(PatternType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if patternType == .incremental {
                                    HStack {
                                        Text("Start:")
                                        TextField("Value", text: $startValue)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 80)
                                    }
                                }
                                
                                Button("Generate") {
                                    generatePattern()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(8)
                        }
                        
                        // Byte operations
                        GroupBox(label: Label("Byte Operations", systemImage: "arrow.left.arrow.right")) {
                            VStack(spacing: 8) {
                                Button(action: reverseBytes) {
                                    Label("Reverse Bytes", systemImage: "arrow.triangle.2.circlepath")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: swapEndianness) {
                                    Label("Swap Endianness (16-bit)", systemImage: "arrow.up.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: zeroSelection) {
                                    Label("Zero Out", systemImage: "0.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                        }
                        
                        // Export
                        GroupBox(label: Label("Export", systemImage: "square.and.arrow.up")) {
                            VStack(spacing: 8) {
                                Button(action: { showExportPanel = true }) {
                                    Label("Export Selection to File", systemImage: "doc.badge.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button(action: copyAsHex) {
                                    Label("Copy as Hex", systemImage: "doc.on.clipboard")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
        .frame(width: 450, height: 600)
        .fileExporter(
            isPresented: $showExportPanel,
            document: ExportDocument(data: getSelectionData()),
            contentType: .data,
            defaultFilename: "selection.bin"
        ) { result in
            // Handle export result
        }
        .onChange(of: document.requestDuplicate) { _, newValue in
            if newValue {
                showDuplicateAlert = true
                document.requestDuplicate = false
            }
        }
        .confirmationDialog("Read-Only Document", isPresented: $showDuplicateAlert, titleVisibility: .visible) {
            Button("Duplicate", role: .none) {
                if let filename = document.filename {
                    duplicateFilename = filename + ".duplicated"
                }
                showFileExporter = true
            }
            Button("Edit Directly", role: .destructive) {
                document.readOnly = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This document is read-only. How would you like to proceed?")
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: document,
            contentType: .item,
            defaultFilename: duplicateFilename
        ) { result in
            if case .success(_) = result {
                // Handle duplication success if needed
                // For now just make editable as we are in a sheet
                document.readOnly = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Filters selection to only include valid indices within buffer bounds
    private func validIndices(from selection: Set<Int>) -> [Int] {
        return selection.sorted().filter { $0 >= 0 && $0 < document.buffer.count }
    }
    
    // MARK: - Actions
    
    private func performFill() {
        guard !selection.isEmpty else { return }
        guard let byte = UInt8(fillByte, radix: 16) else { return }

        let sorted = validIndices(from: selection)
        guard !sorted.isEmpty else { return }
        let originalBytes = sorted.map { (index: $0, byte: document.buffer[$0]) }

        // Perform the fill without individual undo registration
        for index in sorted {
            document.replace(at: index, with: byte)
        }

        // Register a single undo for the entire operation
        undoManager?.registerUndo(withTarget: document) { doc in
            for (index, originalByte) in originalBytes {
                doc.replace(at: index, with: originalByte)
            }
        }
    }
    
    private func generatePattern() {
        guard !selection.isEmpty else { return }
        let sorted = validIndices(from: selection)
        guard !sorted.isEmpty else { return }
        let originalBytes = sorted.map { (index: $0, byte: document.buffer[$0]) }

        // Perform the pattern generation without individual undo registration
        switch patternType {
        case .incremental:
            guard let start = UInt8(startValue, radix: 16) else { return }
            for (i, index) in sorted.enumerated() {
                let byte = UInt8((Int(start) + i) % 256)
                document.replace(at: index, with: byte)
            }

        case .random:
            for index in sorted {
                let byte = UInt8.random(in: 0...255)
                document.replace(at: index, with: byte)
            }

        case .custom:
            // Could implement custom pattern input
            break
        }

        // Register a single undo for the entire operation
        undoManager?.registerUndo(withTarget: document) { doc in
            for (index, originalByte) in originalBytes {
                doc.replace(at: index, with: originalByte)
            }
        }
    }
    
    private func reverseBytes() {
        guard !selection.isEmpty else { return }
        let sorted = validIndices(from: selection)
        guard !sorted.isEmpty else { return }
        let originalBytes = sorted.map { (index: $0, byte: document.buffer[$0]) }
        let bytes = sorted.map { document.buffer[$0] }
        let reversed = bytes.reversed()

        // Perform the reversal without individual undo registration
        for (index, byte) in zip(sorted, reversed) {
            document.replace(at: index, with: byte)
        }

        // Register a single undo for the entire operation
        undoManager?.registerUndo(withTarget: document) { doc in
            for (index, originalByte) in originalBytes {
                doc.replace(at: index, with: originalByte)
            }
        }
    }
    
    private func swapEndianness() {
        guard !selection.isEmpty else { return }
        let sorted = validIndices(from: selection) // Changed from selection.sorted()
        guard !sorted.isEmpty else { return } // Added guard
        let originalBytes = sorted.map { (index: $0, byte: document.buffer[$0]) }

        // Perform the endianness swap without individual undo registration
        for i in stride(from: 0, to: sorted.count - 1, by: 2) {
            let idx1 = sorted[i]
            let idx2 = sorted[i + 1]
            let byte1 = document.buffer[idx1]
            let byte2 = document.buffer[idx2]

            document.replace(at: idx1, with: byte2)
            document.replace(at: idx2, with: byte1)
        }

        // Register a single undo for the entire operation
        undoManager?.registerUndo(withTarget: document) { doc in
            for (index, originalByte) in originalBytes {
                doc.replace(at: index, with: originalByte)
            }
        }
    }
    
    private func zeroSelection() {
        let sorted = selection.sorted()
        let originalBytes = sorted.map { (index: $0, byte: document.buffer[$0]) }

        // Perform the zeroing without individual undo registration
        for index in sorted {
            document.replace(at: index, with: 0)
        }

        // Register a single undo for the entire operation
        undoManager?.registerUndo(withTarget: document) { doc in
            for (index, originalByte) in originalBytes {
                doc.replace(at: index, with: originalByte)
            }
        }
    }
    
    private func copyAsHex() {
        let sorted = selection.sorted()
        let bytes = sorted.map { document.buffer[$0] }
        let hexString = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hexString, forType: .string)
    }
    
    private func getSelectionData() -> Data {
        let sorted = validIndices(from: selection)
        let bytes = sorted.map { document.buffer[$0] }
        return Data(bytes)
    }
}

// Helper for exporting data
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
