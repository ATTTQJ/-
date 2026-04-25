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
            .padding(.vertical, 4)
            .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.13))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("用水中", systemImage: "drop.fill")
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
                        Text("订单 \(context.attributes.orderNum)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.cyan)
            } compactTrailing: {
                WaterLiveTimerText(state: context.state)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color.cyan)
            }
            .keylineTint(Color.cyan)
        }
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
