import Foundation
import Contacts

/// Gere l'ajout d'une carte au carnet de contacts iOS et la generation de vCard.
enum ContactManager {

    enum ContactError: LocalizedError {
        case accessDenied
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "L'acces aux contacts a ete refuse. Autorisez-le dans Reglages > Confidentialite > Contacts."
            case .saveFailed(let message):
                return "Echec de l'enregistrement du contact : \(message)"
            }
        }
    }

    /// Construit un CNMutableContact a partir d'une carte de visite.
    static func makeContact(from card: BusinessCard) -> CNMutableContact {
        let contact = CNMutableContact()

        // Decoupe basique du nom complet en prenom / nom.
        let nameParts = card.fullName.split(separator: " ")
        if nameParts.count >= 2 {
            contact.givenName = String(nameParts.first!)
            contact.familyName = nameParts.dropFirst().joined(separator: " ")
        } else {
            contact.givenName = card.fullName
        }

        if !card.jobTitle.isEmpty { contact.jobTitle = card.jobTitle }
        if !card.company.isEmpty { contact.organizationName = card.company }

        if !card.email.isEmpty {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: card.email as NSString)
            ]
        }

        var phones: [CNLabeledValue<CNPhoneNumber>] = []
        if !card.phone.isEmpty {
            phones.append(CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: card.phone)))
        }
        if !card.mobile.isEmpty {
            phones.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: card.mobile)))
        }
        contact.phoneNumbers = phones

        if !card.website.isEmpty {
            contact.urlAddresses = [
                CNLabeledValue(label: CNLabelWork, value: card.website as NSString)
            ]
        }

        if !card.address.isEmpty {
            let postal = CNMutablePostalAddress()
            postal.street = card.address
            contact.postalAddresses = [
                CNLabeledValue(label: CNLabelWork, value: postal)
            ]
        }

        if !card.notes.isEmpty {
            contact.note = card.notes
        }

        if let data = card.imageData {
            contact.imageData = data
        }

        return contact
    }

    /// Ajoute la carte au carnet de contacts (demande l'autorisation si besoin).
    static func addToContacts(_ card: BusinessCard) async throws {
        let store = CNContactStore()

        let granted: Bool
        do {
            granted = try await store.requestAccess(for: .contacts)
        } catch {
            throw ContactError.saveFailed(error.localizedDescription)
        }
        guard granted else { throw ContactError.accessDenied }

        let contact = makeContact(from: card)
        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)

        do {
            try store.execute(request)
        } catch {
            throw ContactError.saveFailed(error.localizedDescription)
        }
    }

    /// Genere les donnees vCard (.vcf) d'une carte pour le partage.
    static func vCardData(for card: BusinessCard) throws -> Data {
        let contact = makeContact(from: card)
        return try CNContactVCardSerialization.data(with: [contact])
    }

    /// Ecrit la vCard dans un fichier temporaire et renvoie son URL (pour ShareLink).
    static func vCardFileURL(for card: BusinessCard) throws -> URL {
        let data = try vCardData(for: card)
        let safeName = card.displayTitle
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let fileName = (safeName.isEmpty ? "carte" : safeName) + ".vcf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
