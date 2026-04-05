import SwiftUI

struct HourlyChartView: View {
    let hourlyTokens: [Int]
    var isToday: Bool = true
    @State private var hoveredHour: Int?

    @AppStorage("heatmapTheme") private var themeName = HeatmapTheme.green.rawValue
    private var themeColor: Color {
        (HeatmapTheme(rawValue: themeName) ?? .green).colors[7]
    }

    private var maxTokens: Int {
        max(hourlyTokens.max() ?? 0, 1)
    }

    private var peakHourLabel: String? {
        guard let peak = hourlyTokens.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 else {
            return nil
        }
        return String(format: "%02d:00 peak", peak.offset)
    }

    var body: some View {
        PanelCard(
            title: isToday ? "Hourly Activity" : "Selected Day Activity",
            subtitle: "Distribution of tokens across the day",
            systemImage: "clock",
            trailing: AnyView(
                Text(peakHourLabel ?? "No activity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            )
        ) {
            VStack(spacing: 10) {
                chartWithTooltip
                    .frame(height: 92)

                HStack {
                    Text("0")
                    Spacer()
                    Text("6")
                    Spacer()
                    Text("12")
                    Spacer()
                    Text("18")
                    Spacer()
                    Text("23")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var chartWithTooltip: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let barWidth = max(3, (geo.size.width - spacing * 23) / 24)
            let barStep = barWidth + spacing
            let chartHeight = geo.size.height
            let tooltipWidth: CGFloat = 104

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<24, id: \.self) { hour in
                    let tokens = hourlyTokens[hour]
                    let barH = max(tokens > 0 ? 6 : 2, chartHeight * CGFloat(tokens) / CGFloat(maxTokens))

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: hour))
                            .frame(width: barWidth, height: barH)
                            .onHover { isHovered in
                                hoveredHour = isHovered ? hour : nil
                            }
                    }
                    .frame(height: chartHeight)
                }
            }

            if let hour = hoveredHour {
                let tokens = hourlyTokens[hour]
                let barH = max(tokens > 0 ? 6 : 2, chartHeight * CGFloat(tokens) / CGFloat(maxTokens))
                let barCenter = barStep * CGFloat(hour) + barWidth / 2
                let idealX = barCenter - tooltipWidth / 2
                let clampedX = min(max(idealX, 0), geo.size.width - tooltipWidth)
                let tooltipY = chartHeight - barH - 18

                Text("\(String(format: "%02d", hour)):00  \(TokenFormatter.format(tokens))")
                    .font(.system(size: 10).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
                    .frame(width: tooltipWidth)
                    .position(x: clampedX + tooltipWidth / 2, y: max(tooltipY, 8))
                    .allowsHitTesting(false)
            }
        }
    }

    private func barColor(for hour: Int) -> Color {
        if hour == hoveredHour {
            return themeColor
        }
        let tokens = hourlyTokens[hour]
        guard tokens > 0 else { return themeColor.opacity(0.14) }
        let ratio = Double(tokens) / Double(maxTokens)
        return themeColor.opacity(0.28 + 0.72 * ratio)
    }
}
