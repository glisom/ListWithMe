import SwiftUI

struct SortMenuView: View {
    @Binding var selectedOption: SortOption

    var body: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    selectedOption = option
                } label: {
                    HStack {
                        Label(option.rawValue, systemImage: option.icon)
                        if option == selectedOption {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.title3)
        }
    }
}

#Preview {
    @Previewable @State var option: SortOption = .manual
    SortMenuView(selectedOption: $option)
}
