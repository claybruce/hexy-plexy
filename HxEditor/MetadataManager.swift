//
//  MetadataManager.swift
//  HxEditor
//
//  Manages custom file metadata persistence
//

import Foundation
import SwiftUI
import Combine

class MetadataManager: ObservableObject {
    struct Metadata: Codable {
        var customFields: [String: String]
        var notes: String
        var tags: [String]
        var bookmarks: [Bookmark]
        
        struct Bookmark: Codable, Identifiable {
            var id = UUID()
            var offset: Int
            var name: String
            var color: String
        }
        
        init() {
            self.customFields = [:]
            self.notes = ""
            self.tags = []
            self.bookmarks = []
        }
    }
    
    @Published var metadata: Metadata = Metadata()
    
    private var fileURL: URL?
    
    func load(for fileURL: URL) {
        self.fileURL = fileURL
        
        let metadataURL = getMetadataURL(for: fileURL)
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            // No metadata file exists, use defaults
            metadata = Metadata()
            return
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            metadata = try decoder.decode(Metadata.self, from: data)
        } catch {
            print("Failed to load metadata: \(error)")
            metadata = Metadata()
        }
    }
    
    func save() {
        guard let fileURL = fileURL else { return }
        
        let metadataURL = getMetadataURL(for: fileURL)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }
    
    private func getMetadataURL(for fileURL: URL) -> URL {
        let directory = fileURL.deletingLastPathComponent()
        let filename = fileURL.lastPathComponent
        let metadataFilename = ".\(filename).hexeditor-metadata"
        return directory.appendingPathComponent(metadataFilename)
    }
    
    // Convenience methods
    
    func addCustomField(key: String, value: String) {
        metadata.customFields[key] = value
        save()
    }
    
    func removeCustomField(key: String) {
        metadata.customFields.removeValue(forKey: key)
        save()
    }
    
    func updateNotes(_ notes: String) {
        metadata.notes = notes
        save()
    }
    
    func addTag(_ tag: String) {
        if !metadata.tags.contains(tag) {
            metadata.tags.append(tag)
            save()
        }
    }
    
    func removeTag(_ tag: String) {
        metadata.tags.removeAll { $0 == tag }
        save()
    }
    
    func addBookmark(offset: Int, name: String, color: String) {
        let bookmark = Metadata.Bookmark(offset: offset, name: name, color: color)
        metadata.bookmarks.append(bookmark)
        save()
    }
    
    func removeBookmark(id: UUID) {
        metadata.bookmarks.removeAll { $0.id == id }
        save()
    }
}
