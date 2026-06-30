import UIKit

/// Utilitaires de traitement d'image pour garder un stockage local leger
/// et des listes fluides.
enum ImageProcessing {

    /// Taille max (cote le plus long) de la photo pleine resolution conservee.
    static let maxFullDimension: CGFloat = 1600
    /// Taille de la miniature affichee dans la liste.
    static let thumbnailDimension: CGFloat = 240

    /// Redimensionne une image en respectant le ratio, sans agrandir.
    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Donnees JPEG de la photo pleine resolution (redimensionnee + compressee).
    static func fullImageData(from image: UIImage) -> Data? {
        resized(image, maxDimension: maxFullDimension).jpegData(compressionQuality: 0.8)
    }

    /// Donnees JPEG d'une miniature pour l'affichage en liste.
    static func thumbnailData(from image: UIImage) -> Data? {
        resized(image, maxDimension: thumbnailDimension).jpegData(compressionQuality: 0.7)
    }
}
