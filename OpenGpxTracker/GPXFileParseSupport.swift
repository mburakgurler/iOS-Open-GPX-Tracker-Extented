//
//  GPXFileParseSupport.swift
//  OpenGpxTracker
//
//  Resilient GPX loading for diverse files (encoding, security scope, URL vs Data).
//

import Foundation
import CoreGPX

enum GPXFileParseSupport {

    /// Parses GPX at `url` for display or analysis. Handles security-scoped folders/files and common encoding issues.
    static func parseRoot(fromFileURL url: URL) -> GPXRoot? {
        let folderURL = GPXFileManager.GPXFilesFolderURL
        let folderScoped = folderURL.startAccessingSecurityScopedResource()
        let fileScoped = url.startAccessingSecurityScopedResource()
        defer {
            if fileScoped {
                url.stopAccessingSecurityScopedResource()
            }
            if folderScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        if let parser = GPXParser(withURL: url), let root = parser.parsedData() {
            return root
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let dataParser = GPXParser(withData: data)
        if let root = dataParser.parsedData() {
            return root
        }

        let lossyUTF8 = stripUTF8BOM(String(decoding: data, as: UTF8.self))
        if let parser = GPXParser(withRawString: lossyUTF8), let root = parser.parsedData() {
            return root
        }

        // kCFStringEncodingWindowsLatin1 (0x0500) ≈ CP1252 Western European
        let windowsLatin1 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0500))
        )
        let encodings: [String.Encoding] = [.isoLatin1, windowsLatin1, .macOSRoman]
        for encoding in encodings {
            guard let str = try? String(contentsOf: url, encoding: encoding) else { continue }
            let trimmed = stripUTF8BOM(str)
            guard let parser = GPXParser(withRawString: trimmed), let root = parser.parsedData() else { continue }
            return root
        }

        return nil
    }

    private static func stripUTF8BOM(_ s: String) -> String {
        guard let first = s.unicodeScalars.first, first.value == 0xFEFF else { return s }
        return String(s.unicodeScalars.dropFirst())
    }
}
