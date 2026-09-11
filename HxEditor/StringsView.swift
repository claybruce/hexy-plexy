import SwiftUI
import AppKit

struct StringsView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?

    @State private var foundStrings: [FoundString] = []
    @State private var isScanning = false
    @State private var minLengthString = "4"
    @State private var showAscii = true
    @State private var showUnicode = true
    @State private var selectedString: FoundString?
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Controls
            HStack {
                Text("Strings")
                    .font(.headline)
                
                Spacer()
                
                HStack {
                    Text("Min Length:")
                    TextField("4", text: $minLengthString)
                        .frame(width: 40)
                        .textFieldStyle(.roundedBorder)

                    Toggle("ASCII", isOn: $showAscii)
                    Toggle("Unicode", isOn: $showUnicode)

                    Button("Scan") {
                        scanStrings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)

                    Button("Copy") {
                        copySelectedString()
                    }
                    .disabled(selectedString == nil)
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()

            HStack {
                TextField("Search strings...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Divider()

            let filteredStrings = foundStrings.filter { searchText.isEmpty || $0.value.localizedCaseInsensitiveContains(searchText) }

            if isScanning {
                VStack {
                    Spacer()
                    ProgressView("Scanning...")
                    Spacer()
                }
            } else if foundStrings.isEmpty {
                VStack {
                    Spacer()
                    Text("No strings found or not scanned yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(filteredStrings, id: \.id) { str in
                    HStack {
                        Button(action: { jumpToOffset(str.offset) }) {
                            Text(String(format: "%08X", str.offset))
                                .font(.monospaced(.caption)())
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Text(str.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)

                        Text(str.value)
                            .font(.monospaced(.body)())
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text("Len: \(str.value.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .background(selectedString == str ? Color.accentColor.opacity(0.3) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedString = str
                        selectString(str)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Showing \(filteredStrings.count) of \(foundStrings.count) strings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func scanStrings() {
        guard let minLen = Int(minLengthString), minLen > 0 else { return }
        isScanning = true
        foundStrings = []
        
        Task {
            let allStrings = await StringExtractor.extractStrings(from: document.buffer, minLength: minLen)
            
            await MainActor.run {
                // Filter based on toggles
                self.foundStrings = allStrings.filter { str in
                    if str.type == .ascii && !showAscii { return false }
                    if str.type == .unicode && !showUnicode { return false }
                    return true
                }
                self.isScanning = false
            }
        }
    }
    
    private func selectString(_ str: FoundString) {
        let range = str.offset..<(str.offset + str.length)
        selection = Set(range)
        cursorIndex = str.offset + str.length - 1
        selectionAnchor = str.offset
        // Close? Maybe keep open for browsing
    }

    private func copySelectedString() {
        if let str = selectedString {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str.value, forType: .string)
        }
    }

    private func jumpToOffset(_ offset: Int) {
        cursorIndex = offset
        selectionAnchor = offset
        selection = Set(offset..<(offset + 1))
    }
}
