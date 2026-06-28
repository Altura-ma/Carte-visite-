import Foundation

/// Transforme les lignes de texte reconnues en champs de contact structures.
///
/// Approche heuristique (regex + position/taille du texte) qui fonctionne
/// entierement hors-ligne, sans modele externe.
enum CardTextParser {

    static func parse(lines rawLines: [RecognizedLine]) -> ScannedFields {
        var fields = ScannedFields()
        fields.rawText = rawLines.map(\.text).joined(separator: "\n")

        // Lignes "consommees" pour ne pas reutiliser une ligne dans plusieurs champs.
        var used = Set<Int>()

        // MARK: Email
        for (i, line) in rawLines.enumerated() {
            if let match = firstMatch(emailRegex, in: line.text) {
                fields.email = match.lowercased()
                used.insert(i)
                break
            }
        }

        // MARK: Site web
        for (i, line) in rawLines.enumerated() where !used.contains(i) {
            // On ignore les lignes qui sont des emails.
            if line.text.contains("@") { continue }
            if let match = firstMatch(websiteRegex, in: line.text) {
                fields.website = normalizeWebsite(match)
                used.insert(i)
                break
            }
        }

        // MARK: Telephones (jusqu'a 2 : fixe + mobile)
        var phones: [(String, Bool)] = [] // (numero, estMobile)
        for (i, line) in rawLines.enumerated() where !used.contains(i) {
            let nsrange = NSRange(line.text.startIndex..., in: line.text)
            guard let regex = phoneRegex else { continue }
            let matches = regex.matches(in: line.text, range: nsrange)
            for m in matches {
                guard let r = Range(m.range, in: line.text) else { continue }
                let digits = String(line.text[r]).filter { $0.isNumber || $0 == "+" }
                guard digits.filter(\.isNumber).count >= 8 else { continue }
                let lower = line.text.lowercased()
                let isMobile = lower.contains("mob") || lower.contains("cell") || lower.contains("port")
                    || lower.contains("gsm") || digits.hasPrefix("+336") || digits.hasPrefix("06") || digits.hasPrefix("07")
                phones.append((String(line.text[r]).trimmingCharacters(in: .whitespaces), isMobile))
                used.insert(i)
            }
        }
        if let mobile = phones.first(where: { $0.1 }) {
            fields.mobile = mobile.0
            if let fixed = phones.first(where: { $0.0 != mobile.0 }) {
                fields.phone = fixed.0
            }
        } else if let first = phones.first {
            fields.phone = first.0
            if phones.count > 1 { fields.mobile = phones[1].0 }
        }

        // MARK: Societe (mots-cles juridiques)
        for (i, line) in rawLines.enumerated() where !used.contains(i) {
            if companyRegex?.firstMatch(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)) != nil {
                fields.company = line.text
                used.insert(i)
                break
            }
        }

        // MARK: Intitule de poste (mots-cles metier)
        for (i, line) in rawLines.enumerated() where !used.contains(i) {
            if looksLikeJobTitle(line.text) {
                fields.jobTitle = line.text
                used.insert(i)
                break
            }
        }

        // MARK: Adresse (numero + mots-cles de voie, ou code postal)
        for (i, line) in rawLines.enumerated() where !used.contains(i) {
            if looksLikeAddress(line.text) {
                fields.address = line.text
                used.insert(i)
                break
            }
        }

        // MARK: Nom complet
        // Heuristique : parmi les lignes restantes, on privilegie celle qui a
        // la plus grande police (souvent le nom), qui ressemble a un nom propre.
        let nameCandidates = rawLines.enumerated()
            .filter { !used.contains($0.offset) }
            .filter { looksLikePersonName($0.element.text) }
            .sorted { $0.element.height > $1.element.height }
        if let best = nameCandidates.first {
            fields.fullName = best.element.text
            used.insert(best.offset)
        }

        // MARK: Societe de secours (plus grande ligne restante si vide)
        if fields.company.isEmpty {
            let remaining = rawLines.enumerated()
                .filter { !used.contains($0.offset) }
                .filter { !$0.element.text.contains("@") }
                .sorted { $0.element.height > $1.element.height }
            if let candidate = remaining.first {
                fields.company = candidate.element.text
            }
        }

        return fields
    }

    // MARK: - Regex compilees

    private static let emailRegex = try? NSRegularExpression(
        pattern: "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}", options: [])

    private static let websiteRegex = try? NSRegularExpression(
        pattern: "((https?://)?(www\\.)?[A-Za-z0-9-]+\\.(com|fr|net|org|io|co|eu|app|dev|me|info|biz)([/A-Za-z0-9._-]*)?)",
        options: [.caseInsensitive])

    private static let phoneRegex = try? NSRegularExpression(
        pattern: "(\\+?\\d[\\d\\s().\\-]{7,}\\d)", options: [])

    private static let companyRegex = try? NSRegularExpression(
        pattern: "\\b(SARL|SAS|SA|EURL|SASU|GmbH|Inc|LLC|Ltd|Corp|Co|Group|Groupe|Agency|Studio|Solutions|Technologies)\\b",
        options: [.caseInsensitive])

    // MARK: - Helpers

    private static func firstMatch(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private static func normalizeWebsite(_ raw: String) -> String {
        var site = raw.trimmingCharacters(in: .whitespaces)
        if site.contains("@") { return "" }
        if !site.lowercased().hasPrefix("http") {
            site = "https://" + site
        }
        return site
    }

    private static let jobKeywords = [
        "manager", "directeur", "director", "ceo", "cto", "cfo", "coo", "president",
        "fondateur", "founder", "ingenieur", "engineer", "developpeur", "developer",
        "consultant", "responsable", "charge", "chef", "head", "lead", "designer",
        "commercial", "sales", "marketing", "gerant", "associe", "partner", "avocat",
        "architecte", "comptable", "technicien", "assistant", "coordinateur", "analyst"
    ]

    private static func looksLikeJobTitle(_ text: String) -> Bool {
        let lower = text.lowercased()
        return jobKeywords.contains { lower.contains($0) }
    }

    private static let streetKeywords = [
        "rue", "avenue", "av.", "bd", "boulevard", "impasse", "allee", "place",
        "chemin", "route", "quai", "cours", "street", "st.", "road", "rd", "ave"
    ]

    private static func looksLikeAddress(_ text: String) -> Bool {
        let lower = text.lowercased()
        let hasStreet = streetKeywords.contains { lower.contains($0) }
        // Code postal francais (5 chiffres) ou US zip.
        let hasPostal = text.range(of: "\\b\\d{5}\\b", options: .regularExpression) != nil
        let hasNumber = text.range(of: "\\d", options: .regularExpression) != nil
        return (hasStreet && hasNumber) || hasPostal
    }

    private static func looksLikePersonName(_ text: String) -> Bool {
        if text.contains("@") { return false }
        if text.range(of: "\\d", options: .regularExpression) != nil { return false }
        let words = text.split(separator: " ")
        guard (1...4).contains(words.count) else { return false }
        // Au moins un mot commencant par une majuscule.
        let capitalized = words.filter { $0.first?.isUppercase == true }
        guard capitalized.count >= 1 else { return false }
        // Pas trop long (eviter les slogans).
        return text.count <= 40
    }
}
