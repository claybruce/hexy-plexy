//
//  MetadataEditorView.swift
//  HxEditor
//
//  File metadata editor
//

import SwiftUI

struct MetadataEditorView: View {
    @ObservedObject var document: HexDocument
    @ObservedObject var metadataManager: MetadataManager
    @Binding var isPresented: Bool
    @Binding var selection: Set<Int>
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?
    
    let fileURL: URL?
    let fileSize: Int
    let creationDate: Date?
    let modificationDate: Date?
    
    @State private var selectedTab: MetadataTab = .properties
    @State private var newFieldKey: String = ""
    @State private var newFieldValue: String = ""
    @State private var newTag: String = ""
    @State private var newBookmarkName: String = ""
    @State private var selectedBookmarkColor: Color = .blue
    
    enum MetadataTab: String, CaseIterable {
        case properties = "Properties"
        case custom = "Custom Fields"
        case notes = "Notes"
        case tags = "Tags"
        case bookmarks = "Bookmarks"
        
        var icon: String {
            switch self {
            case .properties: return "doc.text"
            case .custom: return "key"
            case .notes: return "note.text"
            case .tags: return "tag"
            case .bookmarks: return "bookmark"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("File Metadata")
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
            .padding()
            
            Divider()
            
            // Tab bar
            Picker("", selection: $selectedTab) {
                ForEach(MetadataTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .properties:
                        propertiesView
                    case .custom:
                        customFieldsView
                    case .notes:
                        notesView
                    case .tags:
                        tagsView
                    case .bookmarks:
                        bookmarksView
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
    
    @ViewBuilder
    private var propertiesView: some View {
        GroupBox(label: Label("File Information", systemImage: "doc.text")) {
            VStack(alignment: .leading, spacing: 8) {
                if let url = fileURL {
                    metadataRow(title: "Filename", value: url.lastPathComponent)
                    metadataRow(title: "Path", value: url.path)
                }
                
                metadataRow(title: "Size", value: formatFileSize(fileSize))
                
                if let created = creationDate {
                    metadataRow(title: "Created", value: formatDate(created))
                }
                
                if let modified = modificationDate {
                    metadataRow(title: "Modified", value: formatDate(modified))
                }
                
                metadataRow(title: "Bytes", value: "\(fileSize)")
            }
            .padding(8)
        }
        
        if let url = fileURL {
            GroupBox(label: Label("File Attributes", systemImage: "gearshape")) {
                VStack(alignment: .leading, spacing: 8) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                        if let permissions = attrs[.posixPermissions] as? NSNumber {
                            let permString = String(format: "%o", permissions.intValue)
                            metadataRow(title: "Permissions", value: permString)
                        }
                        
                        if let type = attrs[.type] as? FileAttributeType {
                            metadataRow(title: "Type", value: "\(type)")
                        }
                    }
                }
                .padding(8)
            }
        }
    }
    
    @ViewBuilder
    private var customFieldsView: some View {
        GroupBox(label: Label("Custom Metadata Fields", systemImage: "key")) {
            VStack(alignment: .leading, spacing: 12) {
                // Add new field
                HStack {
                    TextField("Key", text: $newFieldKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: $newFieldValue)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addCustomField) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newFieldKey.isEmpty)
                }
                
                Divider()
                
                // Existing fields
                if metadataManager.metadata.customFields.isEmpty {
                    Text("No custom fields")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(metadataManager.metadata.customFields.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption.bold())
                                .frame(width: 120, alignment: .leading)
                            Text(metadataManager.metadata.customFields[key] ?? "")
                                .font(.caption)
                            Spacer()
                            Button(action: { metadataManager.removeCustomField(key: key) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private var notesView: some View {
        GroupBox(label: Label("Notes & Comments", systemImage: "note.text")) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: Binding(
                    get: { metadataManager.metadata.notes },
                    set: { metadataManager.updateNotes($0) }
                ))
                .font(.body)
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.2))
                
                Text("Notes are automatically saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private var tagsView: some View {
        GroupBox(label: Label("Tags", systemImage: "tag")) {
            VStack(alignment: .leading, spacing: 12) {
                // Add new tag
                HStack {
                    TextField("New tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTag)
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newTag.isEmpty)
                }
                
                Divider()
                
                // Existing tags
                if metadataManager.metadata.tags.isEmpty {
                    Text("No tags")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.vertical, 8)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(metadataManager.metadata.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button(action: { metadataManager.removeTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(8)
        }
    }
    
    @ViewBuilder
    private var bookmarksView: some View {
        GroupBox(label: Label("Bookmarks", systemImage: "bookmark")) {
            VStack(alignment: .leading, spacing: 12) {
                // Add new bookmark from selection
                HStack {
                    TextField("Bookmark name", text: $newBookmarkName)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: $selectedBookmarkColor)
                        .labelsHidden()
                    Button(action: addBookmark) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newBookmarkName.isEmpty || selection.isEmpty)
                }
                
                if selection.isEmpty {
                    Text("Select bytes in the hex view first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let min = selection.min() {
                    Text("Current selection: offset 0x\(String(format: "%X", min))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Existing bookmarks
                if metadataManager.metadata.bookmarks.isEmpty {
                    Text("No bookmarks")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.vertical, 8)
                } else {
                    ForEach(metadataManager.metadata.bookmarks) { bookmark in
                        HStack {
                            Circle()
                                .fill(colorFromString(bookmark.color))
                                .frame(width: 12, height: 12)
                            Text(bookmark.name)
                                .font(.caption)
                            Spacer()
                            Text(String(format: "0x%X", bookmark.offset))
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Button(action: { jumpToBookmark(bookmark) }) {
                                Image(systemName: "arrow.right.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Jump to offset")
                            Button(action: { metadataManager.removeBookmark(id: bookmark.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(8)
        }
    }
    
    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func addCustomField() {
        guard !newFieldKey.isEmpty else { return }
        metadataManager.addCustomField(key: newFieldKey, value: newFieldValue)
        newFieldKey = ""
        newFieldValue = ""
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        metadataManager.addTag(newTag)
        newTag = ""
    }
    
    private func addBookmark() {
        guard !newBookmarkName.isEmpty, let min = selection.min() else { return }
        let colorString = colorToString(selectedBookmarkColor)
        metadataManager.addBookmark(offset: min, name: newBookmarkName, color: colorString)
        newBookmarkName = ""
    }
    
    private func jumpToBookmark(_ bookmark: MetadataManager.Metadata.Bookmark) {
        selection = [bookmark.offset]
        cursorIndex = bookmark.offset
        selectionAnchor = bookmark.offset
        isPresented = false
    }
    
    private func colorToString(_ color: Color) -> String {
        // Convert Color to hex string
        if let components = NSColor(color).cgColor.components {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return "#0000FF"
    }
    
    private func colorFromString(_ string: String) -> Color {
        // Convert hex string to Color
        let hex = string.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.count == 6 {
            let scanner = Scanner(string: hex)
            var rgb: UInt64 = 0
            if scanner.scanHexInt64(&rgb) {
                let r = Double((rgb >> 16) & 0xFF) / 255.0
                let g = Double((rgb >> 8) & 0xFF) / 255.0
                let b = Double(rgb & 0xFF) / 255.0
                return Color(red: r, green: g, blue: b)
            }
        }
        return .blue
    }
}

// Simple FlowLayout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > (proposal.width ?? 0) {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
                totalWidth = max(totalWidth, lineWidth)
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                totalWidth = max(totalWidth, lineWidth)
            }
        }
        
        totalHeight += lineHeight
        
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for index in subviews.indices {
            if lineX + sizes[index].width > bounds.maxX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            
            let position = CGPoint(x: lineX + sizes[index].width / 2, y: lineY + sizes[index].height / 2)
            subviews[index].place(at: position, anchor: .center, proposal: .unspecified)
            
            lineHeight = max(lineHeight, sizes[index].height)
            lineX += sizes[index].width + spacing
        }
    }
}
