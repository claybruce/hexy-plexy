import SwiftUI

struct JumpToOffsetView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?
    @Binding var isPresented: Bool
    @State private var offsetString: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Jump to Offset")
                .font(.headline)
            
            TextField("Offset (Hex)", text: $offsetString)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    jump()
                }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Jump") {
                    jump()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
    
    private func jump() {
        let cleanString = offsetString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let offset = Int(cleanString, radix: 16) {
            if offset >= 0 && offset < document.buffer.count {
                selection = [offset]
                cursorIndex = offset
                selectionAnchor = offset
                isPresented = false
            }
        }
    }
}
