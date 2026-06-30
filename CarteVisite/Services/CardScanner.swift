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
    /// Vrai si un code QR/barre a ete detecte et exploite sur la carte.
    var detectedQRCode = false
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

    /// Analyse complete : OCR du texte **et** lecture des codes QR / codes-barres.
    ///
    /// Les donnees d'un code QR (vCard, MECARD, URL…) sont structurees et donc
    /// considerees comme fiables : elles ont priorite sur le texte reconnu.
    static func scan(_ image: UIImage) async throws -> ScannedFields {
        let lines = (try? await recognizeLines(in: image)) ?? []
        let payloads = (try? await recognizeBarcodes(in: image)) ?? []

        guard !lines.isEmpty || !payloads.isEmpty else { throw ScanError.noText }

        var fields = lines.isEmpty ? ScannedFields() : CardTextParser.parse(lines: lines)

        // Fusion des donnees du code QR (prioritaires sur l'OCR).
        if let qr = BarcodeParser.parse(payloads: payloads) {
            fields = merge(ocr: fields, qr: qr)
            fields.detectedQRCode = true
            let qrText = payloads.joined(separator: "\n")
            fields.rawText = fields.rawText.isEmpty ? qrText : fields.rawText + "\n\n[QR]\n" + qrText
        }

        return fields
    }

    /// Remplace les champs OCR par ceux du code QR lorsqu'ils sont renseignes.
    private static func merge(ocr: ScannedFields, qr: ScannedFields) -> ScannedFields {
        var r = ocr
        if !qr.fullName.isEmpty { r.fullName = qr.fullName }
        if !qr.jobTitle.isEmpty { r.jobTitle = qr.jobTitle }
        if !qr.company.isEmpty { r.company = qr.company }
        if !qr.email.isEmpty { r.email = qr.email }
        if !qr.phone.isEmpty { r.phone = qr.phone }
        if !qr.mobile.isEmpty { r.mobile = qr.mobile }
        if !qr.website.isEmpty { r.website = qr.website }
        if !qr.address.isEmpty { r.address = qr.address }
        return r
    }

    /// Lit les codes QR / codes-barres presents sur l'image (Vision, en local).
    static func recognizeBarcodes(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNBarcodeObservation]) ?? []
                let payloads = observations.compactMap { $0.payloadStringValue }
                continuation.resume(returning: payloads)
            }
            request.symbologies = [.qr, .aztec, .dataMatrix, .pdf417]

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
