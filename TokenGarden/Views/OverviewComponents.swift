import SwiftUI

struct PanelCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let trailing: AnyView?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                trailing
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let note: String?
    var accent: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SegmentedPillBar<Option: Hashable & CaseIterable>: View where Option.AllCases: RandomAccessCollection {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    init(_ type: Option.Type, selection: Binding<Option>, title: @escaping (Option) -> String) {
        self.options = Array(type.allCases)
        self._selection = selection
        self.title = title
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(size: 11, weight: selection == option ? .semibold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == option
                                ? Color.accentColor.opacity(0.18)
                                : Color.primary.opacity(0.05),
                            in: Capsule()
                        )
                        .foregroundStyle(selection == option ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
