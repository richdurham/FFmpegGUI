import SwiftUI

struct OutputFileSelectionView: View {
    @Binding var path: String
    let selectAction: () -> Void

    var body: some View {
        GroupBox("Output File") {
            HStack {
                TextField("Select output location...", text: $path)
                    .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    selectAction()
                }
            }
            .padding(8)
        }
    }
}
