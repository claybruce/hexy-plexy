//
//  StatusBarView.swift
//  HxEditor
//
//  Status bar showing file and selection information
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isOverwriteMode: Bool
    @Binding var hexInputMode: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // File size
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(formatFileSize(document.buffer.count))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            // Current offset
            if let offset = selection.min() {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption)
                    Text("Offset: 0x\(String(format: "%X", offset)) (\(offset))")
                        .font(.caption.monospaced())
                }
                .foregroundColor(.secondary)
            }
            
            // Selection info
            if selection.count > 1 {
                Divider()
                    .frame(height: 12)
                
                HStack(spacing: 4) {
                    Image(systemName: "selection.pin.in.out")
                        .font(.caption)
                    Text("Selected: \(selection.count) bytes")
                        .font(.caption)
                    
                    if let min = selection.min(), let max = selection.max() {
                        Text("(0x\(String(format: "%X", min))-0x\(String(format: "%X", max)))")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()

            // Edit mode toggle (INS / OVR)
            HStack(spacing: 0) {
                Button(action: {
                    isOverwriteMode = false
                }) {
                    Text("INS")
                        .font(.caption.bold())
                        .foregroundColor(isOverwriteMode ? .secondary : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isOverwriteMode ? Color.clear : Color.blue)
                        )
                }
                .buttonStyle(.plain)

                Button(action: {
                    isOverwriteMode = true
                }) {
                    Text("OVR")
                        .font(.caption.bold())
                        .foregroundColor(isOverwriteMode ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isOverwriteMode ? Color.orange : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )

            // Editing mode toggle (ASCII / HEX)
            HStack(spacing: 0) {
                Button(action: {
                    hexInputMode = false
                }) {
                    Text("ASCII")
                        .font(.caption.bold())
                        .foregroundColor(hexInputMode ? .secondary : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(hexInputMode ? Color.clear : Color.blue)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    hexInputMode = true
                }) {
                    Text("HEX")
                        .font(.caption.bold())
                        .foregroundColor(hexInputMode ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(hexInputMode ? Color.green : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
