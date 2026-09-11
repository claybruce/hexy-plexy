import SwiftUI

struct BitmapView: View {
    @ObservedObject var document: HexDocument
    @Binding var isPresented: Bool
    
    @State private var width: Double = 256
    @State private var pixelFormat: PixelFormat = .grayscale
    @State private var scale: Double = 1.0
    @State private var renderedImage: CGImage?
    @State private var isRendering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Text("Bitmap Visualizer")
                    .font(.system(size: 13, weight: .semibold))

                Divider()

                HStack(spacing: 6) {
                    Text("Width:")
                        .font(.system(size: 11))
                    Slider(value: $width, in: 1...1024, step: 1)
                        .frame(width: 100)
                    Text("\(Int(width))")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 30)
                }

                Picker("", selection: $pixelFormat) {
                    ForEach(PixelFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .font(.system(size: 11))

                Divider()

                HStack(spacing: 2) {
                    Button(action: { scale = max(0.5, scale - 0.5) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)

                    Text("\(Int(scale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 30)

                    Button(action: { scale = min(10.0, scale + 0.5) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: 48)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Image Area
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if let image = renderedImage {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: CGFloat(image.width) * scale,
                                height: CGFloat(image.height) * scale
                            )
                            .padding()
                    } else {
                        VStack {
                            Spacer()
                            if isRendering {
                                ProgressView("Rendering...")
                            } else {
                                Text("No image")
                            }
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: width) {
            render()
        }
        .onChange(of: pixelFormat) {
            render()
        }
        .onAppear {
            render()
        }
    }
    
    private func render() {
        isRendering = true
        let currentWidth = Int(width)
        let currentFormat = pixelFormat
        
        // Debounce slightly or just run
        Task {
            let image = BitmapRenderer.render(buffer: document.buffer, width: currentWidth, format: currentFormat)
            await MainActor.run {
                self.renderedImage = image
                self.isRendering = false
            }
        }
    }
}
