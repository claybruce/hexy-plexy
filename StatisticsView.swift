import SwiftUI

struct StatisticsView: View {
    @ObservedObject var document: HexDocument
    @Binding var isPresented: Bool
    
    @State private var byteCounts: [Int] = Array(repeating: 0, count: 256)
    @State private var entropy: Double = 0.0
    @State private var isLoading = true
    @State private var mostCommonByte: (value: UInt8, count: Int)?
    @State private var leastCommonByte: (value: UInt8, count: Int)?
    @State private var nullByteCount: Int = 0
    @State private var printableCount: Int = 0
    @State private var controlCharCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("File Statistics")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("\(document.buffer.count) bytes analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
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
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Analyzing file...")
                        .controlSize(.large)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Quick Stats Cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            statCard(
                                title: "Unique Bytes",
                                value: "\(byteCounts.filter { $0 > 0 }.count)",
                                subtitle: "out of 256",
                                icon: "number.circle.fill",
                                color: .blue
                            )
                            
                            statCard(
                                title: "Null Bytes",
                                value: "\(nullByteCount)",
                                subtitle: String(format: "%.1f%%", nullBytePercentage),
                                icon: "0.circle.fill",
                                color: .purple
                            )
                            
                            statCard(
                                title: "Printable",
                                value: "\(printableCount)",
                                subtitle: String(format: "%.1f%%", printablePercentage),
                                icon: "text.quote",
                                color: .green
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Entropy Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.title3)
                                    .foregroundStyle(entropyColor)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(entropyColor.opacity(0.15))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Shannon Entropy")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(entropyDescription)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "%.4f", entropy))
                                    .font(.title2.monospaced())
                                    .fontWeight(.bold)
                                    .foregroundColor(entropyColor)
                            }
                            
                            ProgressView(value: entropy, total: 8.0)
                                .tint(entropyColor)
                                .frame(height: 8)
                            
                            HStack {
                                Text("0.0 (Ordered)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("8.0 (Random)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Byte Distribution Histogram
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color.cyan.opacity(0.15))
                                    )
                                
                                Text("Byte Distribution")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                            }
                            
                            GeometryReader { geometry in
                                HStack(alignment: .bottom, spacing: 0) {
                                    if let maxCount = byteCounts.max(), maxCount > 0 {
                                        ForEach(0..<256, id: \.self) { i in
                                            let count = byteCounts[i]
                                            let height = CGFloat(count) / CGFloat(maxCount) * geometry.size.height
                                            
                                            Rectangle()
                                                .fill(barColor(for: i))
                                                .frame(width: geometry.size.width / 256, height: max(height, 0.5))
                                                .help("0x\(String(format: "%02X", i)): \(count) (\(String(format: "%.2f", Double(count) / Double(document.buffer.count) * 100))%)")
                                        }
                                    }
                                }
                            }
                            .frame(height: 120)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            
                            HStack {
                                Text("0x00")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("0x7F")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("0xFF")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Common/Uncommon Bytes
                        HStack(spacing: 12) {
                            // Most Common
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.orange)
                                        .imageScale(.small)
                                    Text("Most Common")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                if let most = mostCommonByte {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("0x\(String(format: "%02X", most.value))")
                                            .font(.title3.monospaced())
                                            .fontWeight(.bold)
                                        Text("\(most.count) times (\(String(format: "%.2f", Double(most.count) / Double(document.buffer.count) * 100))%)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("N/A")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            
                            // Least Common (non-zero)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.teal)
                                        .imageScale(.small)
                                    Text("Least Common")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                if let least = leastCommonByte {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("0x\(String(format: "%02X", least.value))")
                                            .font(.title3.monospaced())
                                            .fontWeight(.bold)
                                        Text("\(least.count) times (\(String(format: "%.2f", Double(least.count) / Double(document.buffer.count) * 100))%)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("N/A")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(width: 650, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            calculateStatistics()
        }
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .imageScale(.small)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
    
    private var nullBytePercentage: Double {
        guard document.buffer.count > 0 else { return 0 }
        return Double(nullByteCount) / Double(document.buffer.count) * 100
    }
    
    private var printablePercentage: Double {
        guard document.buffer.count > 0 else { return 0 }
        return Double(printableCount) / Double(document.buffer.count) * 100
    }
    
    private var entropyColor: Color {
        if entropy < 4.0 { return .green }
        if entropy < 7.0 { return .orange }
        return .red
    }
    
    private var entropyDescription: String {
        if entropy < 3.0 {
            return "Highly structured data"
        } else if entropy < 5.0 {
            return "Moderately compressed"
        } else if entropy < 7.5 {
            return "Compressed or encrypted"
        } else {
            return "Random or encrypted data"
        }
    }
    
    private func barColor(for byteValue: Int) -> Color {
        // Color bars based on byte range
        if byteValue == 0 {
            return .purple.opacity(0.8)
        } else if byteValue < 32 {
            return .red.opacity(0.7) // Control characters
        } else if byteValue < 127 {
            return .green.opacity(0.7) // Printable ASCII
        } else if byteValue == 127 {
            return .red.opacity(0.7) // DEL
        } else {
            return .blue.opacity(0.7) // Extended ASCII
        }
    }
    
    private func calculateStatistics() {
        isLoading = true
        let buffer = document.buffer
        
        Task {
            var counts = Array(repeating: 0, count: 256)
            var nulls = 0
            var printable = 0
            var control = 0
            
            for byte in buffer {
                counts[Int(byte)] += 1
                
                if byte == 0 {
                    nulls += 1
                } else if byte >= 32 && byte < 127 {
                    printable += 1
                } else if byte < 32 || byte == 127 {
                    control += 1
                }
            }
            
            // Calculate Entropy: H = -sum(p_i * log2(p_i))
            var ent: Double = 0.0
            let total = Double(buffer.count)
            if total > 0 {
                for count in counts {
                    if count > 0 {
                        let p = Double(count) / total
                        ent -= p * log2(p)
                    }
                }
            }
            
            // Find most and least common bytes
            var mostCommon: (value: UInt8, count: Int)?
            var leastCommon: (value: UInt8, count: Int)?
            
            for (byte, count) in counts.enumerated() {
                if count > 0 {
                    if mostCommon == nil || count > mostCommon!.count {
                        mostCommon = (UInt8(byte), count)
                    }
                    if leastCommon == nil || count < leastCommon!.count {
                        leastCommon = (UInt8(byte), count)
                    }
                }
            }
            
            await MainActor.run {
                self.byteCounts = counts
                self.entropy = ent
                self.nullByteCount = nulls
                self.printableCount = printable
                self.controlCharCount = control
                self.mostCommonByte = mostCommon
                self.leastCommonByte = leastCommon
                self.isLoading = false
            }
        }
    }
}
