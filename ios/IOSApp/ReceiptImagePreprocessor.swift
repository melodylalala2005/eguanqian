import Foundation
import UIKit

enum ReceiptImagePreprocessorError: LocalizedError {
    case invalidImageData
    case compressionFailed
    case fileWriteFailed(Error)
    case missingCachesDirectory

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "无法读取图片数据，请重试或选择其他图片。"
        case .compressionFailed:
            return "图片压缩失败，请稍后再试。"
        case let .fileWriteFailed(error):
            return "图片保存失败：\(error.localizedDescription)"
        case .missingCachesDirectory:
            return "找不到缓存目录，无法保存图片。"
        }
    }
}

@MainActor
struct ReceiptImagePreprocessor {
    struct ProcessedImage {
        let data: Data
        let originalDimensions: CGSize
        let outputDimensions: CGSize
        let originalFileSize: Int
        let compressedFileSize: Int
        let compressionQuality: CGFloat
        let suggestedFilename: String

        @discardableResult
        func persist(
            to directory: URL? = nil,
            fileManager: FileManager = .default
        ) throws -> URL {
            let targetDirectory: URL
            if let directory {
                targetDirectory = directory
            } else if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                targetDirectory = caches.appendingPathComponent("ReceiptRecognitions", isDirectory: true)
            } else {
                throw ReceiptImagePreprocessorError.missingCachesDirectory
            }

            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            let filename = suggestedFilename.lowercased().hasSuffix(".jpg") ? suggestedFilename : "\(suggestedFilename).jpg"
            let fileURL = targetDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: fileURL, options: [.atomic])
                return fileURL
            } catch {
                throw ReceiptImagePreprocessorError.fileWriteFailed(error)
            }
        }
    }

    private let uuidProvider: () -> UUID
    private let jpegQuality: CGFloat

    init(
        uuidProvider: @escaping () -> UUID = UUID.init,
        jpegQuality: CGFloat = 1.0
    ) {
        self.uuidProvider = uuidProvider
        self.jpegQuality = jpegQuality
    }

    func process(imageData: Data, suggestedFilename: String? = nil) throws -> ProcessedImage {
        guard let image = UIImage(data: imageData) else {
            throw ReceiptImagePreprocessorError.invalidImageData
        }
        return try process(image: image, originalFileSize: imageData.count, suggestedFilename: suggestedFilename)
    }

    private func process(image: UIImage, originalFileSize: Int, suggestedFilename: String?) throws -> ProcessedImage {
        let normalized = normalizedImage(image)

        guard let jpegData = normalized.jpegData(compressionQuality: jpegQuality) else {
            throw ReceiptImagePreprocessorError.compressionFailed
        }

        return ProcessedImage(
            data: jpegData,
            originalDimensions: image.size,
            outputDimensions: normalized.size,
            originalFileSize: originalFileSize,
            compressedFileSize: jpegData.count,
            compressionQuality: jpegQuality,
            suggestedFilename: (suggestedFilename ?? uuidProvider().uuidString)
        )
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? image
    }
}
