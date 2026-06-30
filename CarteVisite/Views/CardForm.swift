import SwiftUI

/// Brouillon editable des champs d'une carte (utilise pour l'ajout et l'edition).
struct CardDraft {
    var fullName = ""
    var jobTitle = ""
    var company = ""
    var email = ""
    var phone = ""
    var mobile = ""
    var website = ""
    var address = ""
    var notes = ""
    var tags: [String] = []

    init() {}

    init(from fields: ScannedFields) {
        fullName = fields.fullName
        jobTitle = fields.jobTitle
        company = fields.company
        email = fields.email
        phone = fields.phone
        mobile = fields.mobile
        website = fields.website
        address = fields.address
    }

    init(from card: BusinessCard) {
        fullName = card.fullName
        jobTitle = card.jobTitle
        company = card.company
        email = card.email
        phone = card.phone
        mobile = card.mobile
        website = card.website
        address = card.address
        notes = card.notes
        tags = card.tags
    }

    /// Applique le brouillon sur un objet carte (edition).
    func apply(to card: BusinessCard) {
        card.fullName = fullName
        card.jobTitle = jobTitle
        card.company = company
        card.email = email
        card.phone = phone
        card.mobile = mobile
        card.website = website
        card.address = address
        card.notes = notes
        card.tags = tags
    }
}

/// Formulaire reutilisable des champs d'une carte.
struct CardFormFields: View {
    @Binding var draft: CardDraft

    var body: some View {
        Section("Identite") {
            LabeledField(label: "Nom complet", systemImage: "person", text: $draft.fullName)
            LabeledField(label: "Poste", systemImage: "briefcase", text: $draft.jobTitle)
            LabeledField(label: "Societe", systemImage: "building.2", text: $draft.company)
        }

        Section("Coordonnees") {
            LabeledField(label: "Email", systemImage: "envelope", text: $draft.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            LabeledField(label: "Telephone", systemImage: "phone", text: $draft.phone)
                .keyboardType(.phonePad)
            LabeledField(label: "Mobile", systemImage: "iphone", text: $draft.mobile)
                .keyboardType(.phonePad)
            LabeledField(label: "Site web", systemImage: "globe", text: $draft.website)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            LabeledField(label: "Adresse", systemImage: "mappin.and.ellipse", text: $draft.address)
        }

        Section("Etiquettes") {
            TagsEditor(tags: $draft.tags)
        }

        Section("Notes") {
            TextField("Notes…", text: $draft.notes, axis: .vertical)
                .lineLimit(2...5)
        }
    }
}

/// Un champ de texte avec icone et libelle.
struct LabeledField: View {
    let label: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(label, text: $text)
        }
    }
}
