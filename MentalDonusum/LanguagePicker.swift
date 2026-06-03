import SwiftUI

struct LanguagePicker: View {
    @Binding var selection: String
    let includeAuto: Bool

    var body: some View {
        Picker("", selection: $selection) {
            if includeAuto {
                Text("Otomatik algıla").tag("")
            }
            ForEach(LanguageCatalog.languages, id: \.code) { lang in
                Text(lang.name).tag(lang.code)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
}

enum LanguageCatalog {
    struct Language {
        let code: String
        let name: String
    }

    static let languages: [Language] = [
        .init(code: "tr", name: "Türkçe"),
        .init(code: "en", name: "İngilizce"),
        .init(code: "de", name: "Almanca"),
        .init(code: "fr", name: "Fransızca"),
        .init(code: "es", name: "İspanyolca"),
        .init(code: "it", name: "İtalyanca"),
        .init(code: "pt", name: "Portekizce"),
        .init(code: "nl", name: "Felemenkçe"),
        .init(code: "pl", name: "Lehçe"),
        .init(code: "ru", name: "Rusça"),
        .init(code: "uk", name: "Ukraynaca"),
        .init(code: "ar", name: "Arapça"),
        .init(code: "zh-Hans", name: "Çince (Basitleştirilmiş)"),
        .init(code: "zh-Hant", name: "Çince (Geleneksel)"),
        .init(code: "ja", name: "Japonca"),
        .init(code: "ko", name: "Korece"),
        .init(code: "hi", name: "Hintçe"),
        .init(code: "id", name: "Endonezce"),
        .init(code: "th", name: "Tayca"),
        .init(code: "vi", name: "Vietnamca")
    ]

    static func displayName(for code: String, autoLabel: String = "Otomatik") -> String {
        if code.isEmpty { return autoLabel }
        if let match = languages.first(where: { $0.code == code }) {
            return match.name
        }
        return code
    }
}
