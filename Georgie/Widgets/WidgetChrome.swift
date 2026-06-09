import SwiftUI

struct WidgetChrome: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager
    let visible: Bool

    var body: some View {
        HStack(spacing: 10) {

            Label(instance.title, systemImage: instance.kind.symbol)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WindowDragHandle())

            HStack(spacing: 4) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(value: $instance.opacity, in: 0.2...1.0)
                    .controlSize(.mini)
                    .frame(width: 110)
            }

            Menu {
                Picker("", selection: $instance.level) {
                    ForEach(FloatLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "square.3.layers.3d.top.filled")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 18)
            .help("Window Level")

            Button {
                instance.clickThrough.toggle()
            } label: {
                Image(systemName: instance.clickThrough ? "cursorarrow.slash" : "cursorarrow")
            }
            .buttonStyle(.borderless)
            .help(instance.clickThrough
                  ? "Click-through on — click to turn off (this top strip stays clickable)"
                  : "Enable click-through (clicks pass through the window)")

            Button {
                manager.close(instance)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(6)
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: visible)
    }
}
