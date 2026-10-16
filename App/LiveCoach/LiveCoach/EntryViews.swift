import SwiftUI
import LifeCoachCore

struct EntryRow: View {
    let entry: Entry

    private var isReminder: Bool { entry.kind == .reminder }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isReminder ? "clock" : "note.text")
                .foregroundStyle(isReminder ? Color.orange : Color.secondary)
                .frame(width: 22)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text.isEmpty ? entry.rawText : entry.text)
                    .font(.body)
                    .strikethrough(entry.doneAt != nil)
                    .foregroundStyle(entry.doneAt != nil ? Color.secondary : Color.primary)

                HStack(spacing: 8) {
                    if let due = entry.dueAt {
                        Label(due.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if entry.isPrivate {
                        Label("privat", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(entry.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if entry.doneAt != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: Entry

    var body: some View {
        NavigationStack {
            Form {
                Section("Typ") {
                    Picker("Typ", selection: $entry.kind) {
                        Label("Notiz", systemImage: "note.text").tag(Kind.note)
                        Label("Erinnerung", systemImage: "clock").tag(Kind.reminder)
                    }
                    .pickerStyle(.segmented)
                }

                if entry.kind == .reminder {
                    Section("Fälligkeit") {
                        DatePicker(
                            "Datum & Uhrzeit",
                            selection: Binding(
                                get: { entry.dueAt ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now)! },
                                set: { entry.dueAt = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Originaltext") {
                    Text(entry.rawText)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        Task {
                            // ersetzt beim Ändern, entfernt beim Erledigen/Löschen (CONCEPT Flow B)
                            if entry.kind == .reminder, let due = entry.dueAt, due > .now {
                                await UNReminderScheduler().schedule(entry, now: .now)
                            } else {
                                await UNReminderScheduler().cancel(id: entry.id)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API-Key", text: Bindable(settings).apiKey)
                        .textContentType(.password)
                    if settings.isManualMode {
                        Label("Manueller Modus – kein API-Key gesetzt", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Label("Haiku-Brücke aktiv", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                } header: {
                    Text("Anthropic API-Key")
                } footer: {
                    Text("Der Key wird in der Keychain gespeichert und verlässt das Gerät nicht.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EntryRow(entry: Entry(rawText: "morgen 10 uhr mama anrufen", text: "Mama anrufen", kind: .reminder,
                          dueAt: Date.now.addingTimeInterval(3600)))
}
