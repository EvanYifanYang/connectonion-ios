import Foundation
import UniformTypeIdentifiers

enum AttachmentEncoding {
    static let defaultMaxAttachmentCount = 10
    static let defaultMaxFileSizeBytes = 10 * 1024 * 1024

    static func dataURL(for data: Data, mimeType: String) -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    static func mimeType(for contentType: UTType?, fallbackFilename: String? = nil) -> String {
        if let mimeType = contentType?.preferredMIMEType {
            return mimeType
        }

        if let fallbackFilename,
           let extensionName = fallbackFilename.split(separator: ".").last,
           let inferredType = UTType(filenameExtension: String(extensionName)),
           let mimeType = inferredType.preferredMIMEType {
            return mimeType
        }

        return "application/octet-stream"
    }

    static func filenameExtension(for contentType: UTType?, fallback: String = "bin") -> String {
        contentType?.preferredFilenameExtension ?? fallback
    }

    static func fileAttachment(name: String, contentType: UTType?, data: Data) -> FileAttachment {
        let mimeType = mimeType(for: contentType, fallbackFilename: name)
        return FileAttachment(
            name: name,
            type: mimeType,
            size: data.count,
            dataURL: dataURL(for: data, mimeType: mimeType)
        )
    }

    static func decodedData(from dataURL: String) -> Data? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let payload = dataURL[dataURL.index(after: commaIndex)...]
        return Data(base64Encoded: String(payload))
    }
}
