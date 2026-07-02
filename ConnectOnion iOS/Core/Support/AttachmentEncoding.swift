import Foundation
import UIKit
import UniformTypeIdentifiers

enum AttachmentEncoding {
    static let defaultMaxAttachmentCount = 10
    static let defaultMaxFileSizeBytes = 10 * 1024 * 1024
    static let defaultMaxInputFrameBytes = 900 * 1024
    static let defaultInputFrameSafetyMarginBytes = 64 * 1024

    struct ImagePayload {
        var dataURL: String
        var size: Int
        var encodedSize: Int
        var mimeType: String
        var filenameExtension: String
        var image: UIImage?
    }

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

    static func imagePayload(data: Data, maxEncodedBytes: Int = defaultMaxInputFrameBytes) -> ImagePayload? {
        guard let image = UIImage(data: data) else { return nil }

        let candidates: [(dimension: CGFloat, quality: CGFloat)] = [
            (1600, 0.82),
            (1400, 0.78),
            (1280, 0.74),
            (1152, 0.70),
            (1024, 0.66),
            (896, 0.62),
            (768, 0.58),
            (640, 0.52),
            (512, 0.46),
            (384, 0.42),
            (320, 0.38),
            (256, 0.34)
        ]

        var smallestPayload: ImagePayload?

        for candidate in candidates {
            let scaledImage = image.scaledForTransport(maxDimension: candidate.dimension)
            guard let jpegData = scaledImage.jpegData(compressionQuality: candidate.quality) else { continue }
            let dataURL = dataURL(for: jpegData, mimeType: "image/jpeg")
            let payload = ImagePayload(
                dataURL: dataURL,
                size: jpegData.count,
                encodedSize: dataURL.utf8.count,
                mimeType: "image/jpeg",
                filenameExtension: "jpg",
                image: scaledImage
            )

            if payload.encodedSize <= maxEncodedBytes {
                return payload
            }

            if smallestPayload == nil || payload.encodedSize < smallestPayload!.encodedSize {
                smallestPayload = payload
            }
        }

        guard let smallestPayload, smallestPayload.encodedSize <= maxEncodedBytes else { return nil }
        return smallestPayload
    }

    static func imagePayload(data: Data, maxBytes: Int) -> ImagePayload? {
        imagePayload(data: data, maxEncodedBytes: encodedDataURLSize(forRawByteCount: maxBytes, mimeType: "image/jpeg"))
    }

    static func encodedDataURLSize(forRawByteCount rawByteCount: Int, mimeType: String) -> Int {
        let base64Length = 4 * ((max(0, rawByteCount) + 2) / 3)
        return "data:\(mimeType);base64,".utf8.count + base64Length
    }

    static func estimatedInputFrameBytes(prompt: String, images: [String], files: [FileAttachment]) -> Int {
        let imageBytes = images.reduce(0) { partial, image in
            partial + image.utf8.count + 8
        }
        let fileBytes = files.reduce(0) { partial, file in
            partial + file.name.utf8.count + file.dataURL.utf8.count + 64
        }

        return prompt.utf8.count + imageBytes + fileBytes + 4096
    }

    static func decodedData(from dataURL: String) -> Data? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let payload = dataURL[dataURL.index(after: commaIndex)...]
        return Data(base64Encoded: String(payload))
    }
}

private extension UIImage {
    func scaledForTransport(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return normalizedForJPEG()
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(
            width: max(1, floor(size.width * scale)),
            height: max(1, floor(size.height * scale))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func normalizedForJPEG() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
