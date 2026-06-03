import SwiftUI
import Translation
import AppKit
import NaturalLanguage
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var historyStore = HistoryStore()
    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLanguageCode: String = ""
    @State private var targetLanguageCode: String = "tr"
    @State private var detectedSourceCode: String?
    @State private var resolvedSourceCode: String?
    @State private var configuration: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var errorMessage: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var openedFileName: String?
    @State private var showCopiedToast = false
    @State private var showSettings = false
    @State private var showHistory = false

    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage(HotkeyManager.keyCodeKey) private var hotkeyKeyCode: Int = Int(HotkeyManager.defaultKeyCode)
    @AppStorage(HotkeyManager.modifiersKey) private var hotkeyModifiers: Int = Int(HotkeyManager.defaultModifiers.rawValue)

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }
    private var currentShortcutString: String {
        ShortcutFormatter.string(
            keyCode: UInt16(hotkeyKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(hotkeyModifiers))
        )
    }

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
        .frame(minWidth: 720, minHeight: 420)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: themeRaw) { _, newValue in AppTheme.apply(rawValue: newValue) }
        .onAppear { AppTheme.apply(rawValue: themeRaw) }
        .onChange(of: sourceText) { _, _ in scheduleTranslation() }
        .onChange(of: sourceLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .onChange(of: targetLanguageCode) { _, _ in scheduleTranslation(immediate: true) }
        .translationTask(configuration) { session in
            await performTranslation(with: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .translateFromClipboard)) { _ in
            loadFromClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in
            showHistory = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(store: historyStore) { entry in
                loadEntry(entry)
            }
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
            LanguagePicker(selection: $sourceLanguageCode, includeAuto: true)
                .frame(maxWidth: 180)

            Button {
                swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Dilleri değiştir")
            .disabled(sourceLanguageCode.isEmpty && detectedSourceCode == nil)

            LanguagePicker(selection: $targetLanguageCode, includeAuto: false)
                .frame(maxWidth: 180)

            Spacer()

            if isTranslating {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                showHistory = true
            } label: {
                Label("Geçmiş", systemImage: "clock.arrow.circlepath")
            }
            .keyboardShortcut("y", modifiers: .command)
            .help("Çeviri geçmişi (⌘Y)")

            Button {
                openFile()
            } label: {
                Label("Dosyadan Aç", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Bir .txt / .md dosyasını aç ve çevir (⌘O)")

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
                .frame(minWidth: 280)
            translationPane
                .frame(minWidth: 280)
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

            MultilineTextView(text: $sourceText)
                .overlay(alignment: .topLeading) {
                    if sourceText.isEmpty {
                        placeholderHints
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var placeholderHints: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Çevrilecek metni yazın veya yapıştırın…")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Kısayollar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                shortcutRow(currentShortcutString, "Panodaki metni çevir (her yerden)")
                shortcutRow("⌘V", "Bu alana yapıştır")
                shortcutRow("⌘O", "Dosyadan çeviri")
                shortcutRow("⌘Y", "Geçmiş")
                shortcutRow("⌘S", "Çeviriyi kaydet")
            }
            .padding(.top, 4)
        }
    }

    private func shortcutRow(_ shortcut: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .center)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.30), lineWidth: 1)
                )
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
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
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Çeviriyi kopyala (⌘⇧C)")
                .foregroundStyle(translatedText.isEmpty ? Color.secondary : Color.accentColor)

                Button {
                    saveTranslationToFile()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(translatedText.isEmpty)
                .keyboardShortcut("s", modifiers: .command)
                .help("Çeviriyi bir dosyaya kaydet (⌘S)")
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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

    private func loadEntry(_ entry: HistoryEntry) {
        sourceLanguageCode = entry.sourceLang
        targetLanguageCode = entry.targetLang
        sourceText = entry.sourceText
        translatedText = entry.translatedText
        openedFileName = nil
        errorMessage = nil
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
            if let src = resolvedSourceCode {
                historyStore.add(HistoryEntry(
                    sourceLang: src,
                    targetLang: targetLanguageCode,
                    sourceText: text,
                    translatedText: response.targetText
                ))
            }
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

// MARK: - Custom multiline editor (cursor / placeholder hizalama düzeltmesi)

struct MultilineTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15)
    var inset: NSSize = NSSize(width: 16, height: 14)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.font = font
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = inset
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let cursor = textView.selectedRange()
            textView.string = text
            let newLen = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(cursor.location, newLen), length: 0))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextView
        init(_ parent: MultilineTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 820, height: 520)
}
