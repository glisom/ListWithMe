import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: String?
    let existingCategories: [String]
    @State private var newCategory = ""
    @State private var isAddingNew = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCategory = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("No Category")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                if !existingCategories.isEmpty {
                    Section("Existing Categories") {
                        ForEach(existingCategories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                dismiss()
                            } label: {
                                HStack {
                                    Text(category)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    if isAddingNew {
                        HStack {
                            TextField("New category", text: $newCategory)
                            Button("Add") {
                                if !newCategory.isEmpty {
                                    selectedCategory = newCategory
                                    dismiss()
                                }
                            }
                            .disabled(newCategory.isEmpty)
                        }
                    } else {
                        Button {
                            isAddingNew = true
                        } label: {
                            Label("Add New Category", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var category: String? = "Dairy"
    CategoryPickerView(
        selectedCategory: $category,
        existingCategories: ["Dairy", "Produce", "Meat", "Bakery"]
    )
}
