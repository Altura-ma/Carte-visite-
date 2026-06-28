import Foundation
import Vision
import UIKit

/// Resultat structure de l'analyse d'une carte de visite.
struct ScannedFields {
    var fullName = ""
    var jobTitle = ""
    var company = ""
    var email = ""
    var phone = ""
    var mobile = ""
    var website = ""
    var address = ""
    var rawText = ""
}

/// Une ligne de texte reconnue avec sa position et sa hauteur (taille de police approx.).
struct RecognizedLine {
    let text: String
    /// Position verticale normalisee (1 = haut de l'image, 0 = bas).
    let topY: CGFloat
    /// Hauteur normalisee de la boite englobante (~ taille de la police).
    let height: CGFloat
}

/// Analyse une photo de carte de visite avec le framework Vision d'Apple.
///
/// Tout se passe **en local sur l'appareil** : Vision embarque un moteur de
/// reconnaissance de texte (OCR) qui ne necessite aucune connexion reseau.
enum CardScanner {

    enum ScanError: Error { case invalidImage, noText }

    /// Reconnait le texte d'une image et le structure en champs de contact.
    static func scan(_ image: UIImage) async throws -> ScannedFields {
        let lines = try await recognizeLines(in: image)
        guard !lines.isEmpty else { throw ScanError.noText }
        return CardTextParser.parse(lines: lines)
    }

    /// Etape OCR brute : renvoie les lignes reconnues avec leur position.
    static func recognizeLines(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [RecognizedLine] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return RecognizedLine(
                        text: text,
                        topY: obs.boundingBox.maxY,
                        height: obs.boundingBox.height
                    )
                }
                // De haut en bas, comme on lit une carte.
                continuation.resume(returning: lines.sorted { $0.topY > $1.topY })
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Langues courantes sur les cartes de visite (francais + anglais).
            request.recognitionLanguages = ["fr-FR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension UIImage {
    /// Convertit l'orientation UIKit en orientation CGImagePropertyOrientation pour Vision.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
