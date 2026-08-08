import UIKit
import Photos

enum PhotoSaver {
    enum Error: LocalizedError {
        case authorizationDenied
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Photo library access was denied. Please allow add-only access to save images."
            case .saveFailed:
                return "The photo could not be saved to your library."
            }
        }
    }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw Error.authorizationDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Error.saveFailed)
                }
            }
        }
    }
}
