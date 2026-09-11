//
//  ContentView.swift
//  HxEditor
//
//  Created by guru on 23.11.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var document: HexDocument
    @State private var selection: Set<Int> = []
    @Environment(\.undoManager) var undoManager
    @State private var showJumpToOffset = false
    @State private var showSearch = false
    @State private var showChecksum = false
    @State private var showStatistics = false
    @State private var showQuickActions = false
    @State private var isOverwriteMode = false
    @State private var byteGrouping = 8
    @State private var hexInputMode = false
    @State private var showInspector = true
    @State private var showStrings = false
    @State private var showBitmap = false
    @State private var comparisonMode = false
    @State private var comparisonDocument: HexDocument?
    @State private var showComparisonFilePicker = false
    @State private var cursorIndex: Int? = nil
    @State private var selectionAnchor: Int? = nil
    @State private var showDuplicateAlert = false
    @State private var showFileExporter = false

    @State private var showExport = false
    @State private var showMetadataEditor = false

    @Environment(\.openDocument) private var openDocument
    
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var metadataManager = MetadataManager()
    
    private var duplicateFilename: String {
        let originalName = document.filename ?? "Untitled"
        if let dotIndex = originalName.lastIndex(of: ".") {
            let base = String(originalName[..<dotIndex])
            let ext = String(originalName[dotIndex...])
            return base + ".duplicated" + ext
        } else {
            return originalName + ".duplicated"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if comparisonMode, let compDoc = comparisonDocument {
                // Comparison mode view
                ComparisonContentView(
                    leftDocument: document,
                    rightDocument: compDoc,
                    isPresented: $comparisonMode
                )
            } else {
                // Normal editing mode
                HSplitView {
                    // Main hex grid
                    // Main hex grid
                    HexGridView(
                        document: document,
                        selection: $selection,
                        isOverwriteMode: $isOverwriteMode,
                        hexInputMode: $hexInputMode,
                        byteGrouping: byteGrouping,
                        showSearch: $showSearch,
                        selectionAnchor: $selectionAnchor,
                        cursorIndex: $cursorIndex,
                        bookmarkManager: bookmarkManager
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Enhanced inspector panel
                    if showInspector {
                        FileInfoView(document: document, selection: $selection)
                            .frame(width: 280)
                    }
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Status bar at bottom
                StatusBarView(
                    document: document,
                    selection: $selection,
                    isOverwriteMode: $isOverwriteMode,
                    hexInputMode: $hexInputMode
                )
                .frame(height: 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if showSearch {
                VStack(alignment: .trailing, spacing: 10) {
                    SearchView(
                        document: document,
                        selection: $selection,
                        isPresented: $showSearch,
                        cursorIndex: $cursorIndex,
                        selectionAnchor: $selectionAnchor,
                        undoManager: undoManager
                    )
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Navigation & Search
                Button(action: { showJumpToOffset = true }) {
                    Label("Jump to Offset", systemImage: "arrow.right.circle")
                }
                .help("Jump to a specific offset (⌘J)")

                Button(action: { showSearch.toggle() }) {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Search for data (⌘F)")

                Button(action: { showStrings = true }) {
                    Label("Strings", systemImage: "text.quote")
                }
                .help("Extract strings")

                Divider()

                // Data Analysis
                Button(action: { showStatistics = true }) {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .help("View file statistics")

                Button(action: { showChecksum = true }) {
                    Label("Checksum", systemImage: "number.square")
                }
                .help("Calculate checksums")

                Divider()

                // View & Edit
                Menu {
                    Picker("Grouping", selection: $byteGrouping) {
                        Text("1 Byte").tag(1)
                        Text("2 Bytes").tag(2)
                        Text("4 Bytes").tag(4)
                        Text("8 Bytes").tag(8)
                        Text("16 Bytes").tag(16)
                    }
                } label: {
                    Label("Grouping", systemImage: "square.grid.3x3")
                }
                .help("Change byte grouping")

                Button(action: { showBitmap = true }) {
                    Label("Bitmap", systemImage: "photo")
                }
                .help("Bitmap Visualizer")

                Button(action: { showComparisonFilePicker = true }) {
                    Label("Compare", systemImage: "arrow.left.arrow.right.square")
                }
                .help("Compare with another file")
                .disabled(comparisonMode)

                Button(action: { showQuickActions = true }) {
                    Label("Quick Actions", systemImage: "wand.and.stars")
                }
                .help("Quick editing actions")
                
                Button(action: { showExport = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export data in various formats")
                

                Button(action: { showMetadataEditor = true }) {
                    Label("Metadata", systemImage: "info.circle")
                }
                .help("Edit file metadata")

                Button(action: { showInspector.toggle() }) {
                    Label("Inspector", systemImage: showInspector ? "sidebar.right" : "sidebar.right")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .onChange(of: document.requestDuplicate) { _, newValue in
            if newValue {
                // Only handle if QuickActions is not active (it handles it internally)
                if !showQuickActions {
                    showDuplicateAlert = true
                    document.requestDuplicate = false
                }
            }
        }
        .sheet(isPresented: $showJumpToOffset) {
            JumpToOffsetView(
                document: document,
                selection: $selection,
                cursorIndex: $cursorIndex,
                selectionAnchor: $selectionAnchor,
                isPresented: $showJumpToOffset
            )
        }
        .sheet(isPresented: $showStrings) {
            StringsView(
                document: document,
                selection: $selection,
                isPresented: $showStrings,
                cursorIndex: $cursorIndex,
                selectionAnchor: $selectionAnchor
            )
        }
        .sheet(isPresented: $showChecksum) {
            ChecksumView(document: document, selection: $selection, isPresented: $showChecksum)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(document: document, isPresented: $showStatistics)
        }
        .sheet(isPresented: $showBitmap) {
            BitmapView(document: document, isPresented: $showBitmap)
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsView(document: document, selection: $selection, isPresented: $showQuickActions, undoManager: undoManager)
        }
        .sheet(isPresented: $showExport) {
            ExportView(document: document, selection: $selection, isPresented: $showExport)
        }

        .sheet(isPresented: $showMetadataEditor) {
            MetadataEditorView(
                document: document,
                metadataManager: metadataManager,
                isPresented: $showMetadataEditor,
                selection: $selection,
                cursorIndex: $cursorIndex,
                selectionAnchor: $selectionAnchor,
                fileURL: document.filename.map { URL(fileURLWithPath: $0) },
                fileSize: document.buffer.count,
                creationDate: nil,
                modificationDate: nil
            )
        }
        .confirmationDialog("Read-Only Document", isPresented: $showDuplicateAlert, titleVisibility: .visible) {
            Button("Duplicate", role: .none) {
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
            if case .success(let url) = result {
                UserDefaults.standard.set(true, forKey: "makeEditable")
                Task {
                    do {
                        try await openDocument(at: url)
                    } catch {
                        // Handle error if needed
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showComparisonFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadComparisonFile(url: url)
                }
            case .failure(let error):
                print("Error loading comparison file: \(error.localizedDescription)")
            }
        }
        .onChange(of: comparisonMode) { _, newValue in
            if !newValue {
                // Clean up comparison document when exiting comparison mode
                comparisonDocument = nil
            }
        }
        .onAppear {
            // Select first byte on open
            if selection.isEmpty {
                selection = [0]
                cursorIndex = 0
                selectionAnchor = 0
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                    }
                }
            }
            return true
        }
    }
    
    private func loadComparisonFile(url: URL) {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let doc = HexDocument(initialData: data)
            doc.filename = url.lastPathComponent
            self.comparisonDocument = doc
            self.comparisonMode = true
        } catch {
            print("Failed to load comparison file from \(url): \(error)")
        }
    }
}

#Preview {
    ContentView(document: HexDocument())
}
