import SwiftUI

struct ItemDetailView: View {
    @Binding var item: ListItem
    let existingCategories: [String]
    let onSave: (ListItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var quantity: Int
    @State private var note: String
    @State private var category: String?
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var priority: Priority

    init(item: Binding<ListItem>, existingCategories: [String], onSave: @escaping (ListItem) -> Void) {
        self._item = item
        self.existingCategories = existingCategories
        self.onSave = onSave
        self._text = State(initialValue: item.wrappedValue.text)
        self._quantity = State(initialValue: item.wrappedValue.quantity)
        self._note = State(initialValue: item.wrappedValue.note ?? "")
        self._category = State(initialValue: item.wrappedValue.category)
        self._dueDate = State(initialValue: item.wrappedValue.dueDate ?? Date())
        self._hasDueDate = State(initialValue: item.wrappedValue.dueDate != nil)
        self._priority = State(initialValue: item.wrappedValue.priority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $text)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Label(p.label, systemImage: p.icon).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as String?)
                        ForEach(existingCategories, id: \.self) { cat in
                            Text(cat).tag(cat as String?)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        var updated = item
        updated.text = text
        updated.quantity = quantity
        updated.note = note.isEmpty ? nil : note
        updated.category = category
        updated.dueDate = hasDueDate ? dueDate : nil
        updated.priority = priority
        updated.modifiedAt = Date()
        onSave(updated)
        dismiss()
    }
}

#Preview {
    @Previewable @State var item = ListItem(text: "Milk", createdBy: "user1")
    ItemDetailView(item: $item, existingCategories: ["Dairy", "Produce"], onSave: { _ in })
}
