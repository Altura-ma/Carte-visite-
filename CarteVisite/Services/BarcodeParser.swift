import Foundation
import Contacts

/// Interprete le contenu des codes QR / codes-barres d'une carte de visite.
///
/// Gere les formats les plus courants : vCard, MECARD, URL, mailto:, tel:.
enum BarcodeParser {

    /// Analyse l'ensemble des charges utiles detectees et les combine.
    static func parse(payloads: [String]) -> ScannedFields? {
        var combined: ScannedFields?
        for payload in payloads {
            guard let fields = parseSingle(payload) else { continue }
            combined = combined.map { fill($0, with: fields) } ?? fields
        }
        return combined
    }

    // MARK: - Un seul code

    private static func parseSingle(_ payload: String) -> ScannedFields? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()

        if upper.hasPrefix("BEGIN:VCARD") {
            return parseVCard(trimmed)
        } else if upper.hasPrefix("MECARD:") {
            return parseMECARD(trimmed)
        } else if upper.hasPrefix("MAILTO:") {
            var f = ScannedFields(); f.email = String(trimmed.dropFirst(7)); return f
        } else if upper.hasPrefix("TEL:") {
            var f = ScannedFields(); f.phone = String(trimmed.dropFirst(4)); return f
        } else if upper.hasPrefix("HTTP://") || upper.hasPrefix("HTTPS://") || upper.hasPrefix("WWW.") {
            var f = ScannedFields(); f.website = trimmed; return f
        }
        return nil
    }

    // MARK: - vCard (via le framework Contacts)

    private static func parseVCard(_ string: String) -> ScannedFields? {
        guard let data = string.data(using: .utf8),
              let contacts = try? CNContactVCardSerialization.contacts(with: data),
              let contact = contacts.first else { return nil }

        var f = ScannedFields()
        f.fullName = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        f.jobTitle = contact.jobTitle
        f.company = contact.organizationName
        f.email = contact.emailAddresses.first.map { String($0.value) } ?? ""

        for phone in contact.phoneNumbers {
            let number = phone.value.stringValue
            if phone.label == CNLabelPhoneNumberMobile {
                f.mobile = number
            } else if f.phone.isEmpty {
                f.phone = number
            }
        }
        if f.phone.isEmpty, let first = contact.phoneNumbers.first {
            f.phone = first.value.stringValue
        }

        f.website = contact.urlAddresses.first.map { String($0.value) } ?? ""

        if let addr = contact.postalAddresses.first?.value {
            f.address = [addr.street, addr.postalCode, addr.city]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        return f
    }

    // MARK: - MECARD

    private static func parseMECARD(_ string: String) -> ScannedFields? {
        let body = String(string.dropFirst("MECARD:".count))
        var f = ScannedFields()

        for part in body.components(separatedBy: ";") {
            guard let colon = part.firstIndex(of: ":") else { continue }
            let key = String(part[..<colon]).uppercased()
            let value = String(part[part.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            switch key {
            case "N":
                let comps = value.components(separatedBy: ",")
                if comps.count >= 2 {
                    let last = comps[0].trimmingCharacters(in: .whitespaces)
                    let first = comps[1].trimmingCharacters(in: .whitespaces)
                    f.fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                } else {
                    f.fullName = value
                }
            case "TEL":
                if f.phone.isEmpty { f.phone = value } else if f.mobile.isEmpty { f.mobile = value }
            case "EMAIL":
                f.email = value
            case "URL":
                f.website = value
            case "ORG":
                f.company = value
            case "ADR":
                f.address = value.replacingOccurrences(of: ",", with: " ")
            default:
                break
            }
        }

        let empty = f.fullName.isEmpty && f.email.isEmpty && f.phone.isEmpty
            && f.website.isEmpty && f.company.isEmpty
        return empty ? nil : f
    }

    // MARK: - Helper

    /// Complete les champs vides de `base` avec ceux de `extra`.
    private static func fill(_ base: ScannedFields, with extra: ScannedFields) -> ScannedFields {
        var r = base
        if r.fullName.isEmpty { r.fullName = extra.fullName }
        if r.jobTitle.isEmpty { r.jobTitle = extra.jobTitle }
        if r.company.isEmpty { r.company = extra.company }
        if r.email.isEmpty { r.email = extra.email }
        if r.phone.isEmpty { r.phone = extra.phone }
        if r.mobile.isEmpty { r.mobile = extra.mobile }
        if r.website.isEmpty { r.website = extra.website }
        if r.address.isEmpty { r.address = extra.address }
        return r
    }
}
