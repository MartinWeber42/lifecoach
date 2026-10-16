import SwiftUI
import SwiftData
import LifeCoachCore

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Entry.createdAt) private var entries: [Entry]

    @State private var inputText = ""
    @State private var isBusy = false
    @State private var editingEntry: Entry?
    @State private var showSettings = false
    @State private var pendingAliases: [Extraction.AliasSuggestion] = []
    @State private var queryText: String?
    @State private var querySources: [Entry] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let queryText { queryBubble }
                if !pendingAliases.isEmpty { aliasBanner }
                if entries.isEmpty { emptyState } else { entryList }
                Divider()
                inputBar
            }
            .navigationTitle("LifeCoach")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: exportJSON(), preview: SharePreview("LifeCoach-Gedächtnis")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryDetailView(entry: entry)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var entryList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(entries) { entry in
                    EntryRow(entry: entry)
                        .id(entry.persistentModelID)
                        .onTapGesture { editingEntry = entry }
                        .listRowSeparator(.hidden)
                }
                .onDelete { indices in
                    for i in indices {
                        let id = entries[i].id
                        context.delete(entries[i])
                        Task { await UNReminderScheduler().cancel(id: id) }
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: entries.count) {
                withAnimation {
                    proxy.scrollTo(entries.last?.persistentModelID, anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo(entries.last?.persistentModelID, anchor: .bottom)
                reprocessPending()
                Task { await UNReminderScheduler().rescheduleAll(entries, now: .now) }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Eingabe…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { submitCapture() }

            Button(action: submitCapture) {
                if isBusy {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.blue)
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Extraktion im Hintergrund (MEMORY.md Verarbeitung): läuft nach der Klassifizierung, blockiert nie.
    private func processExtraction(for entry: Entry, input: String) {
        guard !entry.isPrivate, let extractor = settings.extractor else { return }
        Task {
            let facts = (try? context.fetch(FetchDescriptor<Fact>()))?.filter { $0.supersededByID == nil } ?? []
            let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            guard let extraction = try? await extractor.extract(input, facts: facts, people: people, now: .now, timeZone: .current) else { return }
            let suggestions = try? ExtractionApplier().apply(extraction, to: entry, in: context)
            try? context.save()
            if let suggestions, !suggestions.isEmpty {
                pendingAliases.append(contentsOf: suggestions)
            }
        }
    }

    /// Alias-Bestätigung (MEMORY.md, Schicht 3): ein Banner, kein eigener Screen.
    private var aliasBanner: some View {
        let suggestion = pendingAliases[0]
        return HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
            Text("Ist „\(suggestion.alias)“ = \(suggestion.person)?")
            Spacer()
            Button("Ja") { confirmAlias(suggestion) }
                .buttonStyle(.borderedProminent)
            Button("Nein") { pendingAliases.removeAll { $0 == suggestion } }
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.15))
    }

    private func confirmAlias(_ suggestion: Extraction.AliasSuggestion) {
        let name = suggestion.person
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.name == name })
        if let person = try? context.fetch(descriptor).first {
            person.confirm(suggestion.alias)
            try? context.save()
        }
        pendingAliases.removeAll { $0 == suggestion }
    }

    /// Leerer Zustand mit 2–3 Beispiel-Eingaben als Hilfe (ROADMAP M4).
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tipp einfach rein — ich sortiere.")
                .font(.headline)
            Label("„morgen 10 uhr mama anrufen“", systemImage: "clock")
            Label("„lisa wünscht sich eine keramikvase“", systemImage: "note.text")
            Label("„was wünscht sich meine freundin?“", systemImage: "questionmark.bubble")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    /// JSON-Export (CONCEPT Datenschutz: „Handy weg = Gehirn weg“ — Share-Sheet).
    private func exportJSON() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LifeCoach-Export.json")
        try? EntryExport.jsonData(entries).write(to: url)
        return url
    }

    /// Nachverarbeitung beim App-Start (MEMORY.md Verarbeitung): offline Gefallenes aus rawText neu.
    private func reprocessPending() {
        guard settings.classifier != nil || settings.extractor != nil else { return }
        let pending = entries.filter { !$0.isPrivate && $0.processedVersion == nil }
        guard !pending.isEmpty else { return }
        let facts = (try? context.fetch(FetchDescriptor<Fact>())) ?? []
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let reprocessor = Reprocessor(classifier: settings.classifier, extractor: settings.extractor)
        Task {
            for entry in pending {
                let suggestions = await reprocessor.reprocess(entry, facts: facts, people: people, in: context)
                if !suggestions.isEmpty { pendingAliases.append(contentsOf: suggestions) }
            }
            try? context.save()
        }
    }

    /// Abfrage (CONCEPT Flow C): private Treffer → Kandidaten → Antwort, blockiert nie.
    private func runQuery(_ question: String) {
        let query = QueryService(answerer: settings.answerer)
        let facts = (try? context.fetch(FetchDescriptor<Fact>())) ?? []
        let allEntries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        Task {
            let outcome = await query.ask(question, facts: facts, entries: allEntries, people: people)
            switch outcome {
            case .answered(let answer):
                queryText = answer.text
                querySources = answer.sourceIDs.compactMap { id in facts.first { $0.id == id }?.entry }
            case .nothingStored:
                queryText = "Dazu habe ich nichts gespeichert."
                querySources = []
            case .matches(let ids):
                queryText = "Treffer:"
                querySources = ids.compactMap { id in facts.first { $0.id == id }?.entry }
            case .privateEntries(let hits):
                queryText = "Privat — nur auf dem Gerät:"
                querySources = hits
            }
        }
    }

    /// Antwort mit Quellen (CONCEPT Flow C): der Nutzer kann die Antwort selbst prüfen.
    private var queryBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(queryText ?? "")
                    .font(.body)
                Spacer()
                Button {
                    queryText = nil
                    querySources = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(querySources) { entry in
                EntryRow(entry: entry)
                    .onTapGesture { editingEntry = entry }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.08))
    }

    private func submitCapture() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isBusy else { return }
        inputText = ""
        isBusy = true
        let service = CaptureService(classifier: settings.classifier)
        let ctx = context
        Task {
            let outcome = await service.capture(text)
            isBusy = false
            switch outcome {
            case .entry(let entry):
                ctx.insert(entry)
                await UNReminderScheduler().schedule(entry, now: .now)
                processExtraction(for: entry, input: text)
            case .question(let q):
                runQuery(q)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(AppSettings())
}
