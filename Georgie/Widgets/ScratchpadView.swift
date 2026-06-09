import SwiftUI

struct ScratchpadView: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if instance.noteRendered {
                MarkdownPreview(instance: instance, manager: manager)
            } else {
                editor
            }
        }
    }

    private var header: some View {
        HStack {
            Picker("Mode", selection: $instance.noteRendered) {
                Image(systemName: "pencil").tag(false)
                Image(systemName: "eye").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 92)
            Spacer()
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.top, 30)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private var editor: some View {
        TextEditor(text: $instance.text)
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
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
        let cleaned = firstLine
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "- [ ] ", with: "")
            .replacingOccurrences(of: "- [x] ", with: "")
            .trimmingCharacters(in: .whitespaces)
        instance.title = cleaned.isEmpty ? String(localized: "Note") : String(cleaned.prefix(40))
    }
}

private struct MarkdownPreview: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if instance.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Nothing to preview yet — switch to edit mode and start typing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(parseRows()) { item in
                        view(for: item.row)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
    }

    private struct ParsedRow: Identifiable {
        let id: Int
        let row: MarkdownRow
    }

    private enum MarkdownRow {
        case heading(Int, String)
        case bullet(String)
        case numbered(String, String)
        case checklist(Bool, String, Int)
        case quote(String)
        case rule
        case code(String)
        case blank
        case paragraph(String)
    }

    private func parseRows() -> [ParsedRow] {
        var rows: [ParsedRow] = []
        var inCodeBlock = false
        for (index, raw) in instance.text.components(separatedBy: "\n").enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            if inCodeBlock {
                rows.append(ParsedRow(id: index, row: .code(raw)))
                continue
            }
            if let checked = checklistState(trimmed) {
                rows.append(ParsedRow(id: index, row: .checklist(checked, checklistText(trimmed), index)))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                rows.append(ParsedRow(id: index, row: .rule))
            } else if let (level, text) = headingItem(trimmed) {
                rows.append(ParsedRow(id: index, row: .heading(level, text)))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                rows.append(ParsedRow(id: index, row: .bullet(String(trimmed.dropFirst(2)))))
            } else if trimmed.hasPrefix(">") {
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                rows.append(ParsedRow(id: index, row: .quote(text)))
            } else if let (marker, text) = numberedItem(trimmed) {
                rows.append(ParsedRow(id: index, row: .numbered(marker, text)))
            } else if trimmed.isEmpty {
                rows.append(ParsedRow(id: index, row: .blank))
            } else {
                rows.append(ParsedRow(id: index, row: .paragraph(raw)))
            }
        }
        return rows
    }

    // Accepts headings with or without a space after the hashes (#Titel).
    private func headingItem(_ line: String) -> (Int, String)? {
        guard line.hasPrefix("#") else { return nil }
        let level = line.prefix(while: { $0 == "#" }).count
        guard level <= 6 else { return nil }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private func numberedItem(_ line: String) -> (String, String)? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return ("\(digits).", String(rest.dropFirst(2)))
    }

    @ViewBuilder
    private func view(for row: MarkdownRow) -> some View {
        switch row {
        case .heading(let level, let text):
            Text(inline(text)).font(headingFont(level)).padding(.top, 2)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•").foregroundStyle(.secondary)
                Text(inline(text))
                Spacer(minLength: 0)
            }
        case .numbered(let marker, let text):
            HStack(alignment: .top, spacing: 6) {
                Text(marker).foregroundStyle(.secondary).monospacedDigit()
                Text(inline(text))
                Spacer(minLength: 0)
            }
        case .checklist(let checked, let text, let index):
            checklistRow(text: text, checked: checked, index: index)
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 3)
                Text(inline(text)).foregroundStyle(.secondary).italic()
                Spacer(minLength: 0)
            }
        case .rule:
            Divider()
        case .code(let text):
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        case .blank:
            Spacer().frame(height: 4)
        case .paragraph(let text):
            Text(inline(text))
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:  return .title2.bold()
        case 2:  return .title3.bold()
        case 3:  return .headline
        default: return .subheadline.bold()
        }
    }

    private func checklistRow(text: String, checked: Bool, index: Int) -> some View {
        Button {
            toggleChecklist(at: index)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                Text(inline(text))
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? Color.secondary : Color.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checklistState(_ trimmed: String) -> Bool? {
        if trimmed == "- [ ]" || trimmed.hasPrefix("- [ ] ") { return false }
        let lower = trimmed.lowercased()
        if lower == "- [x]" || lower.hasPrefix("- [x] ") { return true }
        return nil
    }

    private func checklistText(_ trimmed: String) -> String {
        String(trimmed.dropFirst(min(6, trimmed.count)))
    }

    private func inline(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string)) ?? AttributedString(string)
    }

    private func toggleChecklist(at index: Int) {
        var lines = instance.text.components(separatedBy: "\n")
        guard lines.indices.contains(index) else { return }
        let line = lines[index]
        if let range = line.range(of: "- [ ]") {
            lines[index] = line.replacingCharacters(in: range, with: "- [x]")
        } else if let range = line.range(of: "- [x]", options: .caseInsensitive) {
            lines[index] = line.replacingCharacters(in: range, with: "- [ ]")
        }
        instance.text = lines.joined(separator: "\n")
        manager.scheduleAutosave()
    }
}
