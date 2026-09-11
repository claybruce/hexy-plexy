//
//  HexInputHelper.swift
//  HxEditor
//
//  Helper for hex input mode functionality
//

import Foundation
import Combine

class HexInputHelper: ObservableObject {
    @Published var isHexInputMode: Bool = false
    @Published var partialHexInput: String = ""
    
    // Parse a hex character and add to partial input
    // Returns completed byte if we have two hex digits, nil otherwise
    func processHexCharacter(_ char: Character) -> UInt8? {
        guard char.isHexDigit else { return nil }
        
        partialHexInput.append(char)
        
        if partialHexInput.count == 2 {
            let byte = UInt8(partialHexInput, radix: 16)
            partialHexInput = ""
            return byte
        }
        
        return nil
    }
    
    // Clear partial input
    func clearPartialInput() {
        partialHexInput = ""
    }
    
    // Toggle hex input mode
    func toggleMode() {
        isHexInputMode.toggle()
        partialHexInput = ""
    }
    
    // Check if a character is a valid hex digit
    func isValidHexChar(_ char: Character) -> Bool {
        return char.isHexDigit
    }
    
    // Convert hex string to bytes
    static func hexStringToBytes(_ hexString: String) -> [UInt8]? {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        
        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            bytes.append(byte)
            index = nextIndex
        }
        
        return bytes
    }
    
    // Convert bytes to hex string
    static func bytesToHexString(_ bytes: [UInt8], separator: String = " ") -> String {
        return bytes.map { String(format: "%02X", $0) }.joined(separator: separator)
    }
}
