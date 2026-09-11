//
//  BookmarkManager.swift
//  HxEditor
//
//  Manage bookmarks for important file offsets
//

import Foundation
import Combine

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var offset: Int
    var name: String
    var note: String
    var color: String // Store as hex color string
    
    init(offset: Int, name: String, note: String = "", color: String = "blue") {
        self.id = UUID()
        self.offset = offset
        self.name = name
        self.note = note
        self.color = color
    }
}

class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = [] {
        didSet {
            updateOffsetSet()
        }
    }

    private var offsetSet: Set<Int> = []

    private func updateOffsetSet() {
        offsetSet = Set(bookmarks.map { $0.offset })
    }
    
    // Add a new bookmark
    func addBookmark(offset: Int, name: String, note: String = "") {
        let bookmark = Bookmark(offset: offset, name: name, note: note)
        bookmarks.append(bookmark)
        bookmarks.sort { $0.offset < $1.offset }
    }
    
    // Remove a bookmark
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    // Remove bookmark at offset
    func removeBookmark(at offset: Int) {
        bookmarks.removeAll { $0.offset == offset }
    }
    
    // Get bookmark at offset
    func bookmark(at offset: Int) -> Bookmark? {
        return bookmarks.first { $0.offset == offset }
    }
    
    // Check if offset has a bookmark
    func hasBookmark(at offset: Int) -> Bool {
        return offsetSet.contains(offset)
    }
    
    // Update bookmark
    func updateBookmark(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
            bookmarks.sort { $0.offset < $1.offset }
        }
    }
    
    // Clear all bookmarks
    func clearAll() {
        bookmarks.removeAll()
    }
}
