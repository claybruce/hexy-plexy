import SwiftUI

struct SearchView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?
    
    @State private var searchString: String = ""
    @State private var replaceString: String = ""
    @State private var isSearching = false
    @State private var isReplacing = false
    @State private var searchError: String?
    @State private var replaceMessage: String?
    @State private var searchMode: SearchMode = .text
    @State private var caseSensitive = false
    @State private var showReplace = false
    @State private var offset = CGSize.zero
    @FocusState private var isFocused: Bool
    
    var undoManager: UndoManager?
    
    enum SearchMode: String, CaseIterable {
        case text = "Text"
        case hex = "Hex"
    }
    
    enum SearchDirection {
        case forward
        case backward
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header / Drag Handle
            HStack {
                Image(systemName: showReplace ? "arrow.left.arrow.right" : "magnifyingglass")
                    .foregroundColor(.secondary)
                Text(showReplace ? "Find & Replace" : "Find")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .focusable(false)
            }
            .padding(.bottom, 4)
            
            // Search Input
            HStack(spacing: 8) {
                TextField(searchMode == .hex ? "Hex Bytes" : "Search Text", text: $searchString)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit {
                        performSearch(direction: .forward)
                    }
                
                Button(action: { performSearch(direction: .backward) }) {
                    Image(systemName: "arrow.left")
                }
                .disabled(searchString.isEmpty)
                .help("Find Previous")
                
                Button(action: { performSearch(direction: .forward) }) {
                    Image(systemName: "arrow.right")
                }
                .disabled(searchString.isEmpty)
                .keyboardShortcut(.defaultAction)
                .help("Find Next")
            }
            
            // Replace section (if enabled)
            if showReplace {
                Divider()
                
                // Replace Input
                HStack(spacing: 8) {
                    TextField(searchMode == .hex ? "Replace Hex" : "Replace Text", text: $replaceString)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: { performReplace(replaceAll: false) }) {
                        Text("Replace")
                            .frame(width: 60)
                    }
                    .disabled(searchString.isEmpty || selection.isEmpty)
                    .help("Replace current match")
                    
                    Button(action: { performReplace(replaceAll: true) }) {
                        Text("All")
                            .frame(width: 40)
                    }
                    .disabled(searchString.isEmpty)
                    .help("Replace all matches")
                }
            }
            
            // Options
            HStack {
                Picker("", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                if searchMode == .text {
                    Toggle("Case Sensitive", isOn: $caseSensitive)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: showReplace ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(showReplace ? "Hide Replace" : "Show Replace")
            }
            
            // Status / Error
            if isSearching {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if isReplacing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Replacing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let error = searchError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let message = replaceMessage {
                Text(message)
                    .foregroundColor(.green)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(Material.regular)
        .cornerRadius(12)
        .shadow(radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(width: value.translation.width, height: value.translation.height)
                }
                .onEnded { value in
                    offset = CGSize(width: value.translation.width, height: value.translation.height)
                }
        )
        .onAppear {
            isFocused = true
        }
    }
    
    private func performSearch(direction: SearchDirection) {
        guard !searchString.isEmpty else { return }
        isSearching = true
        searchError = nil
        
        let query = searchString
        
        // Calculate start index
        let startIndex: Int
        if direction == .forward {
            startIndex = (selection.max() ?? -1) + 1
        } else {
            startIndex = (selection.min() ?? 0) - 1
        }
        
        // Run in background
        Task {
            let searchBytes: [UInt8]?
            
            if searchMode == .hex {
                // Parse hex input - handle spaces and newlines
                let cleaned = query.components(separatedBy: .whitespacesAndNewlines).joined()
                searchBytes = HexInputHelper.hexStringToBytes(cleaned)
                if searchBytes == nil {
                    await MainActor.run {
                        searchError = "Invalid hex format"
                        isSearching = false
                    }
                    return
                }
            } else {
                // Text search
                if caseSensitive {
                    searchBytes = [UInt8](query.data(using: .utf8) ?? Data())
                } else {
                    searchBytes = [UInt8](query.lowercased().data(using: .utf8) ?? Data())
                }
            }
            
            // Safely unwrap searchBytes
            guard let bytes = searchBytes, !bytes.isEmpty else {
                await MainActor.run {
                    searchError = "Invalid search query"
                    isSearching = false
                }
                return
            }
            
            let foundIndex: Int?
            if direction == .forward {
                foundIndex = await findForward(bytes: bytes, start: startIndex)
            } else {
                foundIndex = await findBackward(bytes: bytes, start: startIndex)
            }
            
            if let index = foundIndex {
                await MainActor.run {
                    // Select all matched bytes
                    let range = index..<(index + bytes.count)
                    selection = Set(range)
                    // Update cursor to end of selection for L-to-R feel
                    cursorIndex = index + bytes.count - 1
                    selectionAnchor = index
                    isSearching = false
                }
            } else {
                await MainActor.run {
                    searchError = "Not found"
                    isSearching = false
                }
            }
        }
    }
    
    private func findForward(bytes searchBytes: [UInt8], start: Int) async -> Int? {
        guard !searchBytes.isEmpty else { return nil }
        
        let buffer = document.buffer
        let count = buffer.count
        let searchCount = searchBytes.count
        
        if start >= count { return nil }
        let effectiveStart = max(0, start)
        
        // For case-insensitive text search
        let shouldLowercase = searchMode == .text && !caseSensitive
        
        // Linear search
        for i in effectiveStart..<(count - searchCount + 1) {
            if checkMatch(at: i, buffer: buffer, searchBytes: searchBytes, shouldLowercase: shouldLowercase) {
                return i
            }
            
            // Yield to allow UI updates if long search
            if i % 5000 == 0 {
                await Task.yield()
            }
        }
        
        return nil
    }
    
    private func findBackward(bytes searchBytes: [UInt8], start: Int) async -> Int? {
        guard !searchBytes.isEmpty else { return nil }
        
        let buffer = document.buffer
        let count = buffer.count
        let searchCount = searchBytes.count
        
        if start < 0 { return nil }
        let effectiveStart = min(start, count - searchCount)
        
        // For case-insensitive text search
        let shouldLowercase = searchMode == .text && !caseSensitive
        
        // Linear search backward
        for i in stride(from: effectiveStart, through: 0, by: -1) {
            if checkMatch(at: i, buffer: buffer, searchBytes: searchBytes, shouldLowercase: shouldLowercase) {
                return i
            }
            
            // Yield to allow UI updates if long search
            if i % 5000 == 0 {
                await Task.yield()
            }
        }
        
        return nil
    }
    
    private func checkMatch(at index: Int, buffer: GapBuffer, searchBytes: [UInt8], shouldLowercase: Bool) -> Bool {
        for j in 0..<searchBytes.count {
            let bufferByte = buffer[index + j]
            let searchByte = searchBytes[j]
            
            if shouldLowercase {
                // Compare as lowercase ASCII
                let bufferLower = (bufferByte >= 65 && bufferByte <= 90) ? bufferByte + 32 : bufferByte
                if bufferLower != searchByte {
                    return false
                }
            } else {
                if bufferByte != searchByte {
                    return false
                }
            }
        }
        return true
    }
    
    // MARK: - Replace Operations
    
    private func performReplace(replaceAll: Bool) {
        guard !searchString.isEmpty else { return }
        
        isReplacing = true
        replaceMessage = nil
        searchError = nil
        
        let searchQuery = searchString
        let replaceQuery = replaceString
        
        Task {
            // Parse search bytes
            let searchBytes: [UInt8]?
            if searchMode == .hex {
                let cleaned = searchQuery.components(separatedBy: .whitespacesAndNewlines).joined()
                searchBytes = HexInputHelper.hexStringToBytes(cleaned)
                if searchBytes == nil {
                    await MainActor.run {
                        searchError = "Invalid search hex format"
                        isReplacing = false
                    }
                    return
                }
            } else {
                if caseSensitive {
                    searchBytes = [UInt8](searchQuery.data(using: .utf8) ?? Data())
                } else {
                    searchBytes = [UInt8](searchQuery.lowercased().data(using: .utf8) ?? Data())
                }
            }
            
            // Parse replace bytes
            let replaceBytes: [UInt8]?
            if searchMode == .hex {
                let cleaned = replaceQuery.components(separatedBy: .whitespacesAndNewlines).joined()
                replaceBytes = HexInputHelper.hexStringToBytes(cleaned)
                if replaceBytes == nil {
                    await MainActor.run {
                        searchError = "Invalid replace hex format"
                        isReplacing = false
                    }
                    return
                }
            } else {
                // For text mode, always use the replace string as-is (preserve case)
                replaceBytes = [UInt8](replaceQuery.data(using: .utf8) ?? Data())
            }
            
            guard let sBytes = searchBytes, !sBytes.isEmpty,
                  let rBytes = replaceBytes else {
                await MainActor.run {
                    searchError = "Invalid search or replace query"
                    isReplacing = false
                }
                return
            }
            
            if replaceAll {
                await performReplaceAll(searchBytes: sBytes, replaceBytes: rBytes)
            } else {
                await performReplaceSingle(searchBytes: sBytes, replaceBytes: rBytes)
            }
        }
    }
    
    private func performReplaceSingle(searchBytes: [UInt8], replaceBytes: [UInt8]) async {
        // Check if current selection matches the search pattern
        guard !selection.isEmpty,
              let min = selection.min(),
              let max = selection.max() else {
            await MainActor.run {
                searchError = "No selection or selection doesn't match search"
                isReplacing = false
            }
            return
        }
        
        let selectedSize = max - min + 1
        if selectedSize != searchBytes.count {
            await MainActor.run {
                searchError = "Selection size doesn't match search pattern"
                isReplacing = false
            }
            return
        }
        
        // Verify selection matches search bytes
        let buffer = document.buffer
        let shouldLowercase = searchMode == .text && !caseSensitive
        if !checkMatch(at: min, buffer: buffer, searchBytes: searchBytes, shouldLowercase: shouldLowercase) {
            await MainActor.run {
                searchError = "Selection doesn't match search pattern"
                isReplacing = false
            }
            return
        }
        
        // Perform replace
        await MainActor.run {
            // Delete old bytes and insert new ones
            // Use document methods to ensure read-only check and undo registration
            document.delete(range: min..<(min + searchBytes.count), undoManager: undoManager)
            document.insert(bytes: replaceBytes, at: min, undoManager: undoManager)
            
            // Update selection to new replaced bytes
            selection = Set(min..<(min + replaceBytes.count))
            cursorIndex = min + replaceBytes.count - 1
            selectionAnchor = min
            
            // Only update message if not read-only (or if edit was successful)
            if !document.readOnly {
                replaceMessage = "Replaced 1 occurrence"
            }
            isReplacing = false
            
            // Auto-search for next occurrence
            Task {
                if let nextIndex = await findForward(bytes: searchBytes, start: min + replaceBytes.count) {
                    await MainActor.run {
                        let range = nextIndex..<(nextIndex + searchBytes.count)
                        selection = Set(range)
                        cursorIndex = nextIndex + searchBytes.count - 1
                        selectionAnchor = nextIndex
                    }
                }
            }
        }
    }
    
    private func performReplaceAll(searchBytes: [UInt8], replaceBytes: [UInt8]) async {
        var replacements: [(index: Int, oldBytes: [UInt8], newBytes: [UInt8])] = []
        let buffer = document.buffer
        let count = buffer.count
        let searchCount = searchBytes.count
        let shouldLowercase = searchMode == .text && !caseSensitive
        
        // Find all matches
        var index = 0
        while index <= count - searchCount {
            if checkMatch(at: index, buffer: buffer, searchBytes: searchBytes, shouldLowercase: shouldLowercase) {
                replacements.append((index: index, oldBytes: searchBytes, newBytes: replaceBytes))
                index += searchCount // Skip past this match
            } else {
                index += 1
            }
            
            // Yield periodically
            if index % 5000 == 0 {
                await Task.yield()
            }
        }
        
        if replacements.isEmpty {
            await MainActor.run {
                replaceMessage = "No matches found"
                isReplacing = false
            }
            return
        }
        
        await MainActor.run {
            undoManager?.beginUndoGrouping()
            
            // Perform replacements in reverse order to maintain indices
            for replacement in replacements.reversed() {
                let range = replacement.index..<(replacement.index + searchBytes.count)
                document.delete(range: range, undoManager: undoManager)
                document.insert(bytes: replaceBytes, at: range.lowerBound, undoManager: undoManager)
            }
            
            undoManager?.endUndoGrouping()
            
            // Clear selection
            selection = []
            cursorIndex = nil
            selectionAnchor = nil
            
            if !document.readOnly {
                replaceMessage = "Replaced \(replacements.count) occurrence\(replacements.count == 1 ? "" : "s")"
            }
            isReplacing = false
        }
    }
}
