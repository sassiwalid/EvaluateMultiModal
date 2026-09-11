import CoreGraphics
import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads receipt photos by name from a bundle, ready for an `Attachment`.
public enum ReceiptImages {
    /// Checked in order for loose image files.
    public static let extensions = ["jpg", "jpeg", "png", "heic", "JPG", "JPEG", "PNG", "HEIC"]

    /// Loads the image named `name` (such as "007"): a loose file with any supported extension,
    /// otherwise an image from the bundle's compiled asset catalog.
    public static func load(
        named name: String,
        in bundle: Bundle
    ) throws -> (image: CGImage, orientation: CGImagePropertyOrientation?) {
        if let url = url(named: name, in: bundle) {
            return try load(url)
        }
        if let image = catalogImage(named: name, in: bundle) {
            return (image, nil)
        }
        throw ReceiptImageError.notFound(name)
    }

    /// The loose image file named `name`, trying each supported extension.
    public static func url(named name: String, in bundle: Bundle) -> URL? {
        extensions.lazy.compactMap { bundle.url(forResource: name, withExtension: $0) }.first
    }

    /// Decodes the file without applying its EXIF orientation and returns that orientation
    /// separately, so `Attachment(_:orientation:)` performs the transform as documented.
    private static func load(_ url: URL) throws -> (image: CGImage, orientation: CGImagePropertyOrientation?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ReceiptImageError.unreadable(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:))
        return (image, orientation)
    }

    /// Asset catalogs don't expose EXIF orientation, so these images are passed as they are.
    private static func catalogImage(named name: String, in bundle: Bundle) -> CGImage? {
        #if canImport(UIKit)
        UIImage(named: name, in: bundle, with: nil)?.cgImage
        #else
        bundle.image(forResource: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}

public enum ReceiptImageError: LocalizedError {
    case notFound(String)
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .notFound(let name):
            "No image named \(name) (\(ReceiptImages.extensions.joined(separator: "/")) or asset catalog)."
        case .unreadable(let url):
            "Can't decode image at \(url.path)."
        }
    }
}
