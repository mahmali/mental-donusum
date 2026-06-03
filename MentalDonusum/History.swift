import SwiftUI

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let sourceLang: String
    let targetLang: String
    let sourceText: String
    let translatedText: String

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        sourceLang: String,
        targetLang: String,
        sourceText: String,
        translatedText: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.sourceText = sourceText
        self.translatedText = translatedText
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL
    private let maxEntries = 200

    init() {
        let fm = FileManager.default
        let baseDir: URL
        if let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            baseDir = support.appendingPathComponent("MentalDonusum", isDirectory: true)
        } else {
            baseDir = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.fileURL = baseDir.appendingPathComponent("history.json")
        load()
    }

    func add(_ entry: HistoryEntry) {
        if let first = entries.first,
           first.sourceText == entry.sourceText,
           first.translatedText == entry.translatedText,
           first.sourceLang == entry.sourceLang,
           first.targetLang == entry.targetLang {
            return
        }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    var onSelect: (HistoryEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [HistoryEntry] {
        guard !search.isEmpty else { return store.entries }
        let needle = search.lowercased()
        return store.entries.filter {
            $0.sourceText.lowercased().contains(needle) ||
            $0.translatedText.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Geçmiş")
                    .font(.title2.bold())
                Text("(\(store.entries.count))")
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.entries.isEmpty {
                    Button("Tümünü Sil", role: .destructive) {
                        store.clear()
                    }
                }
                Button("Kapat") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Geçmişte ara", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.10)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 38))
                        .foregroundStyle(.tertiary)
                    Text(store.entries.isEmpty ? "Henüz çeviri yapılmadı." : "Sonuç bulunamadı.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { entry in
                        Button {
                            onSelect(entry)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(LanguageCatalog.displayName(for: entry.sourceLang))
                                        .font(.caption.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(LanguageCatalog.displayName(for: entry.targetLang))
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text(entry.timestamp, format: .dateTime.day().month().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.sourceText)
                                    .lineLimit(2)
                                    .font(.system(size: 13))
                                Text(entry.translatedText)
                                    .lineLimit(2)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Çevirmene Yükle") { onSelect(entry); dismiss() }
                            Button("Sil", role: .destructive) { store.remove(entry) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}
