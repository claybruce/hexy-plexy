import SwiftUI

struct ComparisonContentView: View {
    @ObservedObject var leftDocument: HexDocument
    @ObservedObject var rightDocument: HexDocument
    @Binding var isPresented: Bool
    
    @State private var diffResult: EnhancedDiffResult?
    @State private var isComparing = false
    @State private var currentBlockIndex: Int = 0
    @State private var scrollTarget: ScrollTarget?
    @State private var showOnlyDifferences = false
    @State private var currentVisibleOffset: Int = 0
    
    struct ScrollTarget: Equatable {
        let offset: Int
        let id = UUID()
    }
    
    var leftFileName: String {
        leftDocument.filename ?? "File 1"
    }
    
    var rightFileName: String {
        rightDocument.filename ?? "File 2"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // File names
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(leftFileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(rightFileName)
                        .font(.headline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Statistics
                if let diff = diffResult {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(diff.blocks.count) diff blocks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%% match", diff.matchPercentage))
                            .font(.caption)
                            .foregroundColor(diff.matchPercentage >= 90 ? .green : diff.matchPercentage >= 50 ? .orange : .red)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Navigation controls
                    if !diff.blocks.isEmpty {
                        HStack(spacing: 8) {
                            Text("\(currentBlockIndex + 1) of \(diff.blocks.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                            
                            Button(action: { navigateToPreviousDiff() }) {
                                Image(systemName: "chevron.up")
                            }
                            .keyboardShortcut("[", modifiers: .command)
                            .help("Previous Difference (⌘[)")
                            
                            Button(action: { navigateToNextDiff() }) {
                                Image(systemName: "chevron.down")
                            }
                            .keyboardShortcut("]", modifiers: .command)
                            .help("Next Difference (⌘])")
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                }
                
                // Actions
                Button("Re-Compare") {
                    performComparison()
                }
                .disabled(isComparing)
                
                Toggle(isOn: $showOnlyDifferences) {
                    Image(systemName: showOnlyDifferences ? "eye.slash" : "eye")
                }
                .toggleStyle(.button)
                .help(showOnlyDifferences ? "Show All" : "Show Only Differences")
                
                Button("Exit Comparison") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main comparison view
            if isComparing {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing differences...")
                            .font(.headline)
                        if let diff = diffResult {
                            Text("Found \(diff.blocks.count) diff blocks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    // Left file
                    VStack(spacing: 0) {
                        Text(leftFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        
                        ComparisonHexGridView(
                            document: leftDocument,
                            diffResult: diffResult,
                            isLeftSide: true,
                            scrollTarget: $scrollTarget,
                            currentVisibleOffset: $currentVisibleOffset,
                            showOnlyDifferences: showOnlyDifferences,
                            currentBlockIndex: currentBlockIndex
                        )
                    }
                    
                    // Right file
                    VStack(spacing: 0) {
                        Text(rightFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        
                        ComparisonHexGridView(
                            document: rightDocument,
                            diffResult: diffResult,
                            isLeftSide: false,
                            scrollTarget: $scrollTarget,
                            currentVisibleOffset: $currentVisibleOffset,
                            showOnlyDifferences: showOnlyDifferences,
                            currentBlockIndex: currentBlockIndex
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            performComparison()
        }
    }
    
    private func performComparison() {
        isComparing = true
        
        Task {
            let result = await DiffEngine.compare(buffer1: leftDocument.buffer, buffer2: rightDocument.buffer)
            
            await MainActor.run {
                self.diffResult = result
                self.currentBlockIndex = 0
                self.isComparing = false
                
                // Auto-jump to first difference
                if !result.blocks.isEmpty {
                    jumpToBlock(at: 0)
                }
            }
        }
    }
    
    private func navigateToNextDiff() {
        guard let diff = diffResult, !diff.blocks.isEmpty else { return }
        
        // Simple increment with wrap-around
        currentBlockIndex = (currentBlockIndex + 1) % diff.blocks.count
        jumpToBlock(at: currentBlockIndex)
    }
    
    private func navigateToPreviousDiff() {
        guard let diff = diffResult, !diff.blocks.isEmpty else { return }
        
        // Simple decrement with wrap-around
        currentBlockIndex = (currentBlockIndex - 1 + diff.blocks.count) % diff.blocks.count
        jumpToBlock(at: currentBlockIndex)
    }
    
    private func jumpToBlock(at index: Int) {
        guard let diff = diffResult, index >= 0, index < diff.blocks.count else { return }
        
        let block = diff.blocks[index]
        scrollTarget = ScrollTarget(offset: block.range.lowerBound)
    }
}
