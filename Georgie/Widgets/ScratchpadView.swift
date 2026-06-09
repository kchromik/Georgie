import SwiftUI

struct ScratchpadView: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager

    var body: some View {
        TextEditor(text: $instance.text)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(.top, 30)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .onChange(of: instance.text) {
                deriveTitle()
                manager.scheduleAutosave()
            }
            .onAppear(perform: deriveTitle)
    }

    private func deriveTitle() {
        let firstLine = instance.text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        instance.title = firstLine.isEmpty ? String(localized: "Note") : String(firstLine.prefix(40))
    }
}
