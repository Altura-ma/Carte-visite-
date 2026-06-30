import Foundation
import SwiftData

/// Une carte de visite stockee localement dans le coffre.
///
/// Toutes les donnees (champs + photo) restent sur l'appareil via SwiftData.
/// Aucune information n'est envoyee sur un serveur.
@Model
final class BusinessCard {
    /// Identifiant unique.
    var id: UUID

    // MARK: - Champs du contact
    var fullName: String
    var jobTitle: String
    var company: String
    var email: String
    var phone: String
    var mobile: String
    var website: String
    var address: String
    var notes: String

    /// Texte brut reconnu par l'OCR, conserve pour reference / re-analyse.
    var rawText: String

    /// Photo de la carte (stockee hors de la base pour rester legere).
    @Attribute(.externalStorage) var imageData: Data?

    /// Miniature compressee pour un affichage rapide en liste.
    @Attribute(.externalStorage) var thumbnailData: Data?

    var createdAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        jobTitle: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        mobile: String = "",
        website: String = "",
        address: String = "",
        notes: String = "",
        rawText: String = "",
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.jobTitle = jobTitle
        self.company = company
        self.email = email
        self.phone = phone
        self.mobile = mobile
        self.website = website
        self.address = address
        self.notes = notes
        self.rawText = rawText
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }

    /// Titre affiche dans la liste (nom, sinon societe, sinon "Sans nom").
    var displayTitle: String {
        if !fullName.trimmingCharacters(in: .whitespaces).isEmpty { return fullName }
        if !company.trimmingCharacters(in: .whitespaces).isEmpty { return company }
        return "Sans nom"
    }

    /// Sous-titre affiche dans la liste.
    var displaySubtitle: String {
        let parts = [jobTitle, company].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return parts.joined(separator: " · ")
    }

    /// Initiales pour la vignette quand il n'y a pas de photo.
    var initials: String {
        let source = displayTitle
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }
}
