import SwiftUI
import Translation
import AppKit
import NaturalLanguage
import UniformTypeIdentifiers

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
    @State private var openedFileName: String?
    @State private var showCopiedToast = false

    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

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
        .frame(minWidth: 660, minHeight: 380)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: themeRaw) { _, newValue in
            AppTheme.apply(rawValue: newValue)
        }
        .onAppear {
            AppTheme.apply(rawValue: themeRaw)
        }
        .onChange(of: sourceText) { _, _ in scheduleTranslation() }
        .onChange(of: sourceLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .onChange(of: targetLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .translationTask(configuration) { session in
            await performTranslation(with: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .translateFromClipboard)) { _ in
            loadFromClipboard()
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Kopyalandı")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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
                openFile()
            } label: {
                Label("Dosyadan Aç", systemImage: "folder")
            }
            .help("Bir .txt / .md dosyasını aç ve çevir")

            Button {
                loadFromClipboard()
            } label: {
                Label("Yapıştır", systemImage: "doc.on.clipboard")
            }
            .help("Panodaki metni kaynak alana yapıştır")
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
            HStack(spacing: 8) {
                Text(sourceHeaderLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let openedFileName {
                    Text("· \(openedFileName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("\(sourceText.count) karakter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !sourceText.isEmpty {
                    Button {
                        sourceText = ""
                        translatedText = ""
                        openedFileName = nil
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
            .padding(.bottom, 4)

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
            HStack(spacing: 8) {
                Text(LanguageCatalog.displayName(for: targetLanguageCode, autoLabel: "Hedef"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copyTranslationToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(translatedText.isEmpty)
                .help("Çeviriyi kopyala")
                .foregroundStyle(translatedText.isEmpty ? Color.secondary : Color.accentColor)

                Button {
                    saveTranslationToFile()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(translatedText.isEmpty)
                .help("Çeviriyi bir dosyaya kaydet")
                .foregroundStyle(translatedText.isEmpty ? Color.secondary : Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

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

    // MARK: - Header labels

    private var sourceHeaderLabel: String {
        if !sourceLanguageCode.isEmpty {
            return LanguageCatalog.displayName(for: sourceLanguageCode)
        }
        if let detected = detectedSourceCode {
            return "Otomatik · \(LanguageCatalog.displayName(for: detected))"
        }
        return "Otomatik algıla"
    }

    // MARK: - Actions

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
            openedFileName = nil
            sourceText = text
        }
    }

    private func copyTranslationToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(translatedText, forType: .string)
        flashCopiedToast()
    }

    private func flashCopiedToast() {
        withAnimation(.easeOut(duration: 0.15)) { showCopiedToast = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeIn(duration: 0.25)) { showCopiedToast = false }
        }
    }

    // MARK: - File operations

    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = "Çevrilecek metin dosyası"
        panel.message = "Çevrilecek bir metin dosyası seçin"
        panel.prompt = "Aç"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let plainText = UTType("public.plain-text") {
            panel.allowedContentTypes = [plainText, .text, .utf8PlainText, .rtf, .html]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try readTextFile(at: url)
                openedFileName = url.lastPathComponent
                sourceText = content
                errorMessage = nil
            } catch {
                errorMessage = "Dosya okunamadı: \(error.localizedDescription)"
            }
        }
    }

    private func readTextFile(at url: URL) throws -> String {
        // UTF-8 önce, sonra UTF-16, sonra Latin-1 dene; RTF'i NSAttributedString ile çöz.
        let data = try Data(contentsOf: url)

        if url.pathExtension.lowercased() == "rtf" {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                return attr.string
            }
        }

        for encoding in [String.Encoding.utf8, .utf16, .isoLatin1, .windowsCP1254] {
            if let s = String(data: data, encoding: encoding), !s.isEmpty {
                return s
            }
        }
        throw NSError(domain: "MentalDonusum", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Bilinmeyen metin kodlaması"
        ])
    }

    private func saveTranslationToFile() {
        guard !translatedText.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Çeviriyi Kaydet"
        panel.message = "Çeviri sonucunu bir metin dosyasına kaydet"
        panel.prompt = "Kaydet"
        panel.canCreateDirectories = true
        if let plainText = UTType("public.plain-text") {
            panel.allowedContentTypes = [plainText]
        }
        let baseName = openedFileName.flatMap { $0.split(separator: ".").first.map(String.init) } ?? "ceviri"
        panel.nameFieldStringValue = "\(baseName)-\(targetLanguageCode).txt"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try translatedText.write(to: url, atomically: true, encoding: .utf8)
                errorMessage = nil
            } catch {
                errorMessage = "Kaydedilemedi: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Translation orchestration

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
        let code = dominant.rawValue
        if code == "zh" { return "zh-Hans" }
        return code
    }
}

#Preview {
    ContentView()
        .frame(width: 820, height: 500)
}
