import SwiftUI
import Translation
import AppKit
import NaturalLanguage

struct ContentView: View {
    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLanguageCode: String = ""        // "" = otomatik
    @State private var targetLanguageCode: String = "tr"
    @State private var detectedSourceCode: String?
    @State private var resolvedSourceCode: String?
    @State private var configuration: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var errorMessage: String?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            editorPane
            if let errorMessage {
                Divider()
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 640, minHeight: 360)
        .onChange(of: sourceText) { _, _ in scheduleTranslation() }
        .onChange(of: sourceLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .onChange(of: targetLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .translationTask(configuration) { session in
            await performTranslation(with: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .translateFromClipboard)) { _ in
            loadFromClipboard()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            LanguagePicker(
                selection: $sourceLanguageCode,
                includeAuto: true
            )
            .frame(maxWidth: 180)

            Button {
                swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Dilleri değiştir")
            .disabled(sourceLanguageCode.isEmpty && detectedSourceCode == nil)

            LanguagePicker(
                selection: $targetLanguageCode,
                includeAuto: false
            )
            .frame(maxWidth: 180)

            Spacer()

            if isTranslating {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                loadFromClipboard()
            } label: {
                Label("Panodan yapıştır", systemImage: "doc.on.clipboard")
            }
            .help("Panodaki metni kaynak alana yapıştır")

            Button {
                copyTranslationToClipboard()
            } label: {
                Label("Kopyala", systemImage: "doc.on.doc")
            }
            .disabled(translatedText.isEmpty)
            .help("Çeviri sonucunu panoya kopyala")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Editor

    private var editorPane: some View {
        HSplitView {
            sourcePane
                .frame(minWidth: 260)
            translationPane
                .frame(minWidth: 260)
        }
    }

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(sourceHeaderLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(sourceText.count) karakter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !sourceText.isEmpty {
                    Button {
                        sourceText = ""
                        translatedText = ""
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Temizle")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            TextEditor(text: $sourceText)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(alignment: .topLeading) {
                    if sourceText.isEmpty {
                        Text("Çevrilecek metni buraya yazın veya yapıştırın…")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 15))
                            .padding(.horizontal, 13)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var translationPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LanguageCatalog.displayName(for: targetLanguageCode, autoLabel: "Hedef"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                Text(translatedText.isEmpty ? "Çeviri burada görünecek…" : translatedText)
                    .font(.system(size: 15))
                    .foregroundStyle(translatedText.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.4))
        }
    }

    // MARK: - Actions

    private var sourceHeaderLabel: String {
        if !sourceLanguageCode.isEmpty {
            return LanguageCatalog.displayName(for: sourceLanguageCode)
        }
        if let detected = detectedSourceCode {
            return "Otomatik · \(LanguageCatalog.displayName(for: detected))"
        }
        return "Otomatik algıla"
    }

    private func swapLanguages() {
        let oldSource = sourceLanguageCode.isEmpty
            ? (detectedSourceCode ?? resolvedSourceCode)
            : sourceLanguageCode
        guard let oldSource else { return }
        sourceLanguageCode = targetLanguageCode
        targetLanguageCode = oldSource
        let oldText = sourceText
        sourceText = translatedText
        translatedText = oldText
    }

    private func loadFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            sourceText = text
        }
    }

    private func copyTranslationToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(translatedText, forType: .string)
    }

    private func scheduleTranslation(immediate: Bool = false) {
        debounceTask?.cancel()
        let delayNs: UInt64 = immediate ? 0 : 400_000_000
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNs)
            if Task.isCancelled { return }
            triggerTranslation()
        }
    }

    private func triggerTranslation() {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            errorMessage = nil
            detectedSourceCode = nil
            resolvedSourceCode = nil
            return
        }
        errorMessage = nil

        let effectiveSourceCode: String
        if sourceLanguageCode.isEmpty {
            if let detected = Self.detectLanguageCode(for: trimmed) {
                detectedSourceCode = detected
                effectiveSourceCode = detected
            } else {
                detectedSourceCode = nil
                errorMessage = "Kaynak dil otomatik algılanamadı. Lütfen sol üstten kaynak dili seçin."
                translatedText = ""
                return
            }
        } else {
            detectedSourceCode = nil
            effectiveSourceCode = sourceLanguageCode
        }

        if effectiveSourceCode == targetLanguageCode {
            translatedText = sourceText
            resolvedSourceCode = effectiveSourceCode
            return
        }

        resolvedSourceCode = effectiveSourceCode
        let source = Locale.Language(identifier: effectiveSourceCode)
        let target = Locale.Language(identifier: targetLanguageCode)
        let newConfig = TranslationSession.Configuration(source: source, target: target)
        if configuration == newConfig {
            configuration?.invalidate()
        } else {
            configuration = newConfig
        }
    }

    @MainActor
    private func performTranslation(with session: TranslationSession) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let response = try await session.translate(text)
            translatedText = response.targetText
            errorMessage = nil
        } catch {
            errorMessage = "Çeviri yapılamadı: \(error.localizedDescription)"
        }
    }

    /// `NaturalLanguage` ile baskın dili algılar. Translation framework'ünün
    /// otomatik algılayıcısından çok daha geniş bir aralıkta çalışır.
    static func detectLanguageCode(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else { return nil }
        // NLLanguage.rawValue genelde BCP-47 kodu döner ("en", "tr", "zh-Hans" vb.)
        let code = dominant.rawValue
        // Çince için sistem "zh" döner; Translation BCP-47 bekler — varsayılan basitleştirilmişe yönlendir.
        if code == "zh" { return "zh-Hans" }
        return code
    }
}

#Preview {
    ContentView()
        .frame(width: 820, height: 500)
}
