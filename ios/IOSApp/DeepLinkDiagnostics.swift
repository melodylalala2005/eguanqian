import Foundation
import OSLog

enum DeepLinkDiagnostics {
    private static let logger = Logger(
        subsystem: "com.eguanqian.finance",
        category: "DeepLinkRouting"
    )

    static func log(_ source: String, _ message: String) {
        logger.debug("[\(source, privacy: .public)] \(message, privacy: .public)")
    }
}


