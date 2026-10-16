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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                entryList
                Divider()
                inputBar
            }
            .navigationTitle("LifeCoach")
            .toolbar {
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
                    for i in indices { context.delete(entries[i]) }
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

    private func submitCapture() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isBusy else { return }
        inputText = ""
        isBusy = true
        let service = CaptureService(classifier: settings.classifier)
        let ctx = context
        Task {
            let entry = await service.classify(text)
            ctx.insert(entry)
            isBusy = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(AppSettings())
}
