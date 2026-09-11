import SwiftUI
import UniformTypeIdentifiers
import Combine

final class HexDocument: ReferenceFileDocument {
    @Published var buffer: GapBuffer
    @Published var readOnly: Bool = true
    @Published var requestDuplicate = false
    @Published var filename: String?
    @Published var undoRedoSelectionRange: Range<Int>? = nil

    init(initialData: Data = Data()) {
        self.buffer = GapBuffer(data: initialData)
        self.readOnly = initialData.isEmpty ? false : true
    }

    static var readableContentTypes: [UTType] { [.item] }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.buffer = GapBuffer(data: data)
        self.filename = configuration.file.filename
        if UserDefaults.standard.bool(forKey: "makeEditable") {
            self.readOnly = false
            UserDefaults.standard.set(false, forKey: "makeEditable")
        } else {
            self.readOnly = true
        }
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        return buffer.toData()
    }
    
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: snapshot)
    }
    
    // MARK: - Mutation Methods with Undo Support
    
    func insert(_ byte: UInt8, at index: Int, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        buffer.insert(byte, at: index)
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = index..<(index + 1)
        } else {
            undoRedoSelectionRange = nil
        }

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.delete(at: index, undoManager: undoManager)
        }
    }
    
    func insert(bytes: [UInt8], at index: Int, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        
        buffer.insert(bytes, at: index)
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = index..<(index + bytes.count)
        } else {
            undoRedoSelectionRange = nil
        }

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.delete(indices: Array(index..<(index + bytes.count)), undoManager: undoManager)
        }
    }
    
    func delete(at index: Int, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        let byte = buffer[index]
        buffer.delete(at: index)
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = index..<(index + 1)
        } else {
            undoRedoSelectionRange = nil
        }

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.insert(byte, at: index, undoManager: undoManager)
        }
    }
    
    func delete(range: Range<Int>, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        
        // Capture deleted bytes for undo
        let deletedBytes = buffer.getBytes(in: range)
        
        // Perform deletion
        buffer.delete(in: range)
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = range.lowerBound..<range.lowerBound
        } else {
            undoRedoSelectionRange = nil
        }
        
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.insert(bytes: deletedBytes, at: range.lowerBound, undoManager: undoManager)
        }
    }
    
    func delete(indices: [Int], undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        
        // Sort indices descending to handle deletions from end to start
        // This prevents index shifting affecting subsequent deletions
        let sortedIndices = indices.sorted(by: >)
        
        if sortedIndices.isEmpty { return }
        
        // Group consecutive indices into ranges
        // Since we sorted descending, consecutive indices will be like: 10, 9, 8...
        var ranges: [Range<Int>] = []
        var currentRangeEnd = sortedIndices[0] + 1
        var currentRangeStart = sortedIndices[0]
        
        for i in 1..<sortedIndices.count {
            let index = sortedIndices[i]
            if index == currentRangeStart - 1 {
                // Consecutive, extend current range downwards
                currentRangeStart = index
            } else {
                // Gap found, commit current range and start new one
                ranges.append(currentRangeStart..<currentRangeEnd)
                currentRangeEnd = index + 1
                currentRangeStart = index
            }
        }
        // Commit the last range
        ranges.append(currentRangeStart..<currentRangeEnd)
        
        // Perform deletions
        // Note: We built ranges from descending indices, so the ranges are already in descending order of position.
        // e.g. if indices were [10, 9, 8, 5, 4], ranges are [8..<11, 4..<6]
        // Deleting 8..<11 first is safe, then 4..<6.
        
        undoManager?.beginUndoGrouping()
        for range in ranges {
            delete(range: range, undoManager: undoManager)
        }
        undoManager?.endUndoGrouping()
    }
    
    func replace(at index: Int, with byte: UInt8, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        let oldByte = buffer[index]
        buffer[index] = byte
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = index..<(index + 1)
        } else {
            undoRedoSelectionRange = nil
        }

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.replace(at: index, with: oldByte, undoManager: undoManager)
        }
    }
    
    func replace(bytes: [UInt8], at index: Int, undoManager: UndoManager? = nil) {
        if readOnly {
            requestDuplicate = true
            return
        }
        
        let replaceCount = min(bytes.count, buffer.count - index)
        let insertCount = bytes.count - replaceCount
        
        // Capture old bytes for undo
        var oldBytes: [UInt8] = []
        for i in 0..<replaceCount {
            oldBytes.append(buffer[index + i])
        }
        
        // Perform updates
        for i in 0..<replaceCount {
            buffer[index + i] = bytes[i]
        }
        
        if insertCount > 0 {
            let bytesToInsert = Array(bytes[replaceCount...])
            buffer.insert(bytesToInsert, at: index + replaceCount)
        }
        
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            undoRedoSelectionRange = index..<(index + bytes.count)
        } else {
            undoRedoSelectionRange = nil
        }
        
        undoManager?.registerUndo(withTarget: self) { doc in
            // Group the undo operations so Redo is also one step
            undoManager?.beginUndoGrouping()
            
            // Undo: Delete inserted, Restore replaced
            if insertCount > 0 {
                let start = index + replaceCount
                let end = start + insertCount
                doc.delete(indices: Array(start..<end), undoManager: undoManager)
            }
            
            if replaceCount > 0 {
                doc.replace(bytes: oldBytes, at: index, undoManager: undoManager)
            }
            
            undoManager?.endUndoGrouping()
        }
    }
}
