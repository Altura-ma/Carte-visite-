import SwiftUI

/// Ecran "A propos" : presente le fonctionnement et la confidentialite de l'app.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("Coffre de cartes")
                            .font(.title2.bold())
                        Text(version)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Comment ca marche") {
                    FeatureRow(icon: "camera.viewfinder", title: "Scannez ou importez",
                               text: "Capturez une carte avec l'appareil photo ou choisissez une photo existante.")
                    FeatureRow(icon: "text.viewfinder", title: "Reconnaissance locale",
                               text: "Le texte est analyse directement sur votre appareil avec la technologie Vision d'Apple.")
                    FeatureRow(icon: "person.crop.circle.badge.plus", title: "Contact en 1 clic",
                               text: "Ajoutez la personne a vos contacts instantanement.")
                    FeatureRow(icon: "square.and.arrow.up", title: "Partage",
                               text: "Envoyez une carte au format vCard, avec sa photo.")
                }

                Section("Confidentialite") {
                    Label {
                        Text("Toutes vos cartes restent **sur votre appareil**. Aucune donnee n'est envoyee sur Internet, aucun compte n'est requis.")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                }
            }
            .navigationTitle("A propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
