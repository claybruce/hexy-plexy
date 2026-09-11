//
//  FileInfoView.swift
//  HxEditor
//
//  Enhanced file information and inspector panel
//

import SwiftUI

struct FileInfoView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @State private var isLittleEndian: Bool = true
    @State private var selectedTab: InfoTab = .dataTypes
    
    enum InfoTab: String, CaseIterable {
        case dataTypes = "Data Types"
        case strings = "Strings"
        case selection = "Selection"
        
        var icon: String {
            switch self {
            case .dataTypes: return "number.circle"
            case .strings: return "textformat"
            case .selection: return "selection.pin.in.out"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tab selector
            Picker("View", selection: $selectedTab) {
                ForEach(InfoTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .dataTypes:
                        dataTypesView
                    case .strings:
                        stringsView
                    case .selection:
                        selectionInfoView
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 250, maxWidth: 300)
    }
    
    @ViewBuilder
    private var dataTypesView: some View {
        if let index = selection.min(), index < document.buffer.count {
            Toggle("Little Endian", isOn: $isLittleEndian)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Integer Types")
                inspectorRow(title: "8-bit Signed", value: getValue(at: index, type: Int8.self))
                inspectorRow(title: "8-bit Unsigned", value: getValue(at: index, type: UInt8.self))
                inspectorRow(title: "16-bit Signed", value: getValue(at: index, type: Int16.self))
                inspectorRow(title: "16-bit Unsigned", value: getValue(at: index, type: UInt16.self))
                inspectorRow(title: "32-bit Signed", value: getValue(at: index, type: Int32.self))
                inspectorRow(title: "32-bit Unsigned", value: getValue(at: index, type: UInt32.self))
                inspectorRow(title: "64-bit Signed", value: getValue(at: index, type: Int64.self))
                inspectorRow(title: "64-bit Unsigned", value: getValue(at: index, type: UInt64.self))
                
                Divider()
                    .padding(.vertical, 4)
                
                sectionHeader("Floating Point")
                inspectorRow(title: "Float (32-bit)", value: getValue(at: index, type: Float32.self))
                inspectorRow(title: "Double (64-bit)", value: getValue(at: index, type: Float64.self))
                
                Divider()
                    .padding(.vertical, 4)
                
                sectionHeader("Binary")
                inspectorRow(title: "Binary", value: String(document.buffer[index], radix: 2).padLeft(toLength: 8, withPad: "0"))
            }
        } else {
            Text("No selection")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
    
    @ViewBuilder
    private var stringsView: some View {
        if !selection.isEmpty {
            let sortedIndices = selection.sorted().filter { $0 >= 0 && $0 < document.buffer.count }
            if !sortedIndices.isEmpty {
                let selectedBytes = sortedIndices.map { document.buffer[$0] }
                
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("String Previews (\(selectedBytes.count) bytes)")
                    
                    // ASCII
                    let asciiString = selectedBytes.compactMap { byte in
                        (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : nil
                    }.joined()
                    
                    if !asciiString.isEmpty {
                        inspectorRow(title: "ASCII", value: asciiString.prefix(50).description)
                    } else {
                        inspectorRow(title: "ASCII", value: "(no printable characters)")
                    }
                    
                    // UTF-8
                    let utf8String = String(bytes: selectedBytes, encoding: .utf8) ?? "Invalid UTF-8"
                    inspectorRow(title: "UTF-8", value: utf8String.prefix(50).description)
                    
                    // Raw ASCII (with dots for non-printable)
                    let rawAscii = selectedBytes.map { byte in
                        (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : "·"
                    }.joined()
                    inspectorRow(title: "Raw ASCII", value: rawAscii.prefix(50).description)
                    
                    // Hex dump
                    let hexDump = selectedBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                    inspectorRow(title: "Hex", value: hexDump.prefix(100).description)
                }
            } else {
                Text("Selection out of bounds")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        } else {
            Text("No selection")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
    
    @ViewBuilder
    private var selectionInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("File Information")
            inspectorRow(title: "Total Size", value: formatFileSize(document.buffer.count))
            
            if !selection.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                sectionHeader("Selection")
                
                if let min = selection.min(), let max = selection.max() {
                    inspectorRow(title: "Start", value: "0x\(String(format: "%X", min)) (\(min))")
                    inspectorRow(title: "End", value: "0x\(String(format: "%X", max)) (\(max))")
                    inspectorRow(title: "Length", value: "\(selection.count) bytes")
                    
                    // Selection statistics
                    if selection.count > 0 {
                        Divider()
                            .padding(.vertical, 4)
                        sectionHeader("Statistics")
                        
                        let sortedIndices = selection.sorted().filter { $0 >= 0 && $0 < document.buffer.count }
                        if !sortedIndices.isEmpty {
                            let bytes = sortedIndices.map { document.buffer[$0] }
                            let sum = bytes.reduce(0) { Int($0) + Int($1) }
                            let avg = Double(sum) / Double(bytes.count)
                            
                            inspectorRow(title: "Average", value: String(format: "%.2f", avg))
                            inspectorRow(title: "Min Byte", value: "0x\(String(format: "%02X", bytes.min() ?? 0))")
                            inspectorRow(title: "Max Byte", value: "0x\(String(format: "%02X", bytes.max() ?? 0))")
                        }
                    }
                }
            } else {
                Text("No selection")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
    
    private func inspectorRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
    
    private func getValue<T: Numeric & CustomStringConvertible>(at index: Int, type: T.Type) -> String {
        let size = MemoryLayout<T>.size
        guard index + size <= document.buffer.count else { return "N/A" }
        
        var bytes: [UInt8] = []
        for i in 0..<size {
            bytes.append(document.buffer[index + i])
        }
        
        if isLittleEndian {
            return bytes.withUnsafeBytes { $0.load(as: T.self) }.description
        } else {
            return Array(bytes.reversed()).withUnsafeBytes { $0.load(as: T.self) }.description
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// String extension for padding
extension String {
    func padLeft(toLength: Int, withPad: String) -> String {
        let padCount = max(0, toLength - self.count)
        return String(repeating: withPad, count: padCount) + self
    }
}
