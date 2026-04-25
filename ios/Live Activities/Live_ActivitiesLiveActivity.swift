import ActivityKit
import Foundation
import WidgetKit
import SwiftUI

struct Live_ActivitiesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaterLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.statusText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(context.attributes.deviceName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(.white.opacity(0.72))
                    WaterLiveTimerText(state: context.state)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.13))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Running", systemImage: "drop.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.cyan)
                        Text(context.attributes.deviceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    WaterLiveTimerText(state: context.state)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(orderTail(context.attributes.orderNum))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.cyan)
                    .frame(width: 34, height: 28, alignment: .center)
            } compactTrailing: {
                WaterLiveTimerText(state: context.state)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: 54, height: 28, alignment: .trailing)
            } minimal: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cyan)
            }
            .keylineTint(Color.cyan)
        }
    }

    private func orderTail(_ orderNum: String) -> String {
        let trimmed = orderNum.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        return "Order \(String(trimmed.suffix(5)))"
    }
}

private struct WaterLiveTimerText: View {
    let state: WaterLiveActivityAttributes.ContentState

    var body: some View {
        if state.isRunning {
            Text(state.startedAt, style: .timer)
        } else {
            Text(formatElapsedSeconds(state.elapsedSeconds))
        }
    }

    private func formatElapsedSeconds(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let minutes = safeSeconds / 60
        let remainingSeconds = safeSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}
