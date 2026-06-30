# Coffre de cartes 📇

Application iOS (SwiftUI) qui sert de **répertoire de cartes de visite**. Scannez une
carte, l'app **reconnaît automatiquement le texte en local**, vous laisse corriger les
informations, puis vous permet d'**ajouter le contact en 1 clic** ou de **partager** la carte.

Tout fonctionne **hors-ligne** : aucune donnée ne quitte l'appareil.

## ✨ Fonctionnalités

- **Coffre local** — toutes les cartes sont stockées sur l'appareil via **SwiftData** (photo incluse).
- **Reconnaissance d'image 100% locale** — OCR avec le framework **Vision** d'Apple, qui embarque
  un moteur de reconnaissance de texte sur l'appareil (aucun serveur, aucune IA en ligne).
- **Scan caméra** — détection automatique des bords et correction de perspective via **VisionKit**.
- **Import depuis la photothèque** — analysez une photo existante.
- **Extraction intelligente des champs** — nom, poste, société, email, téléphone, mobile, site web, adresse
  (heuristiques + expressions régulières, voir `CardTextParser.swift`).
- **Lecture des QR codes / codes-barres** — détection locale (`VNDetectBarcodesRequest`) et
  interprétation des formats **vCard, MECARD, URL, mailto:, tel:** (voir `BarcodeParser.swift`).
  Les données structurées du QR sont prioritaires sur l'OCR.
- **Ajout aux contacts en 1 clic** — création d'un contact via le framework **Contacts**.
- **Partage** — génération d'une **vCard (.vcf)** + image, partagées via la feuille système iOS.
- **Export du coffre** — exporte toutes les cartes dans un seul fichier **.vcf** (sauvegarde / migration).
- **Recherche, édition et suppression** des cartes.

## 🧠 Comment marche la reconnaissance « IA locale » ?

L'app n'utilise aucun service en ligne. Le pipeline est :

1. **Capture / import** de l'image de la carte.
2. **`CardScanner`** lance une requête `VNRecognizeTextRequest` (Vision) en mode `accurate`,
   langues `fr-FR` / `en-US`. Le modèle de reconnaissance de texte est embarqué dans iOS.
3. **`CardTextParser`** structure les lignes reconnues en champs de contact à l'aide de la
   position/taille du texte et d'expressions régulières (email, téléphone, site web, mots-clés métier…).
4. L'utilisateur vérifie/corrige, puis la carte est enregistrée dans le coffre local.

## 🛠️ Ouvrir le projet

1. Ouvrez `CarteVisite.xcodeproj` avec **Xcode 16** ou plus récent.
2. Sélectionnez votre équipe de signature (onglet *Signing & Capabilities*) si vous déployez sur un appareil.
3. Le **scan caméra nécessite un vrai iPhone** (le simulateur n'a pas d'appareil photo) ;
   l'import depuis la photothèque et l'OCR fonctionnent aussi dans le simulateur.
4. `⌘R` pour lancer.

- **Cible minimale :** iOS 17.0
- **Bundle identifier :** `com.cartevisite.app` (à personnaliser)

## 📂 Structure

```
CarteVisite/
├─ CarteVisiteApp.swift        # Point d'entrée + conteneur SwiftData
├─ PrivacyInfo.xcprivacy       # Manifeste de confidentialité (App Store)
├─ Assets.xcassets/            # Icône d'app + couleur d'accent
├─ Models/
│  └─ BusinessCard.swift       # Modèle de données local (+ miniature)
├─ Services/
│  ├─ CardScanner.swift        # OCR Vision + lecture QR codes (local)
│  ├─ CardTextParser.swift     # Extraction des champs depuis le texte
│  ├─ BarcodeParser.swift      # Interprétation des QR codes (vCard/MECARD/URL)
│  ├─ ImageProcessing.swift    # Redimensionnement + miniatures
│  └─ ContactManager.swift     # Contacts + vCard + export
└─ Views/
   ├─ CardListView.swift       # Le coffre (liste + recherche + ajout)
   ├─ AddCardView.swift        # Revue après scan (analyse + correction)
   ├─ CardDetailView.swift     # Détail + actions (contact, partage)
   ├─ CardEditView.swift       # Édition
   ├─ CardForm.swift           # Formulaire réutilisable
   ├─ AboutView.swift          # Écran « À propos » + confidentialité
   └─ DocumentScannerView.swift# Scanner VisionKit + feuille de partage
```

## 🚀 Préparer la publication sur l'App Store

L'app est prête à être archivée. Avant de soumettre :

1. **Bundle identifier** — remplacez `com.cartevisite.app` par le vôtre
   (cible *CarteVisite* → *Signing & Capabilities* → *Bundle Identifier*).
2. **Équipe de signature** — sélectionnez votre compte développeur Apple.
3. **Version / build** — `MARKETING_VERSION` (1.0) et `CURRENT_PROJECT_VERSION` (1).
4. **Icône** — fournie (`Assets.xcassets/AppIcon`), 1024×1024, opaque, prête.
5. **Manifeste de confidentialité** — `PrivacyInfo.xcprivacy` est inclus
   (aucun tracking, aucune collecte de données, APIs à raison requise déclarées).
6. **Fiche App Store Connect** — l'app ne collecte aucune donnée : répondez
   « Non » à la collecte de données dans le questionnaire de confidentialité.
7. `Product › Archive` puis distribution via l'Organizer.

> ⚠️ Le **scan caméra nécessite un vrai iPhone**. Testez sur appareil avant soumission.

## 🔐 Permissions

Déclarées dans les réglages du projet (`INFOPLIST_KEY_*`) :

- **Appareil photo** — pour scanner les cartes.
- **Contacts** — pour ajouter un contact.
- **Photothèque** — pour importer une photo de carte.

## 🗺️ Pistes d'amélioration

- Détection de langue automatique et support multilingue étendu.
- Tags / dossiers pour organiser les cartes.
- Synchronisation iCloud (CloudKit) optionnelle.
- Import d'un fichier .vcf existant dans le coffre.
