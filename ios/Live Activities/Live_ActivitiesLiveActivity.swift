import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct Live_ActivitiesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaterLiveActivityAttributes.self) { context in
            WaterLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.13))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WaterIslandHeader(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    WaterIslandTrailingAction(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    WaterIslandBottom(context: context)
                }
            } compactLeading: {
                WaterCompactIcon(context: context)
            } compactTrailing: {
                WaterLiveTimerText(state: context.state)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 52, height: 28, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isRunning ? waterIconName(context) : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(context.state.isRunning ? waterAccentColor(context) : Color.green)
            }
            .keylineTint(context.state.isRunning ? waterAccentColor(context) : Color.green)
        }
    }
}

private struct WaterLockScreenView: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            WaterStatusIcon(context: context, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text(context.state.statusText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(context.attributes.deviceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)

                if context.state.isRunning {
                    WaterLiveTimerText(state: context.state)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    Text("用水 \(formatDuration(context.state.elapsedSeconds))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Spacer(minLength: 8)

            if context.state.isRunning {
                WaterStopButton()
            } else {
                WaterAmountText(state: context.state)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct WaterIslandHeader: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 11) {
            WaterStatusIcon(context: context, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.statusText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(context.attributes.deviceName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: 210, alignment: .leading)
    }
}

private struct WaterIslandTrailingAction: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if context.state.isRunning {
                WaterStopButton()
            } else {
                WaterAmountText(state: context.state)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.bottom, 2)
    }
}

private struct WaterIslandBottom: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(systemName: context.state.isRunning ? "timer" : "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))

            VStack(alignment: .leading, spacing: 3) {
                if context.state.isRunning {
                    WaterLiveTimerText(state: context.state)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } else {
                    WaterAmountText(state: context.state)
                    Text("用水 \(formatDuration(context.state.elapsedSeconds))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}

private struct WaterCompactIcon: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        Image(systemName: context.state.isRunning ? waterIconName(context) : "checkmark.circle.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(context.state.isRunning ? waterAccentColor(context) : Color.green)
            .frame(width: 28, height: 28, alignment: .center)
    }
}

private struct WaterStopButton: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: StopWaterIntent()) {
                Text("结束")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.58, green: 0.18, blue: 0.16))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct WaterStatusIcon: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill((context.state.isRunning ? waterAccentColor(context) : Color.green).opacity(0.18))
            Image(systemName: context.state.isRunning ? waterIconName(context) : "checkmark")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(context.state.isRunning ? waterAccentColor(context) : Color.green)
        }
        .frame(width: size, height: size)
    }
}

private struct WaterAmountText: View {
    let state: WaterLiveActivityAttributes.ContentState

    var body: some View {
        Text(state.amountText.isEmpty ? "已完成" : state.amountText)
            .font(.system(size: state.amountText.isEmpty ? 17 : 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
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
}

private func waterIconName(_ context: ActivityViewContext<WaterLiveActivityAttributes>) -> String {
    context.attributes.isHotWater ? "flame.fill" : "drop.fill"
}

private func waterAccentColor(_ context: ActivityViewContext<WaterLiveActivityAttributes>) -> Color {
    context.attributes.isHotWater ? Color(red: 1.0, green: 0.48, blue: 0.18) : .cyan
}

private func formatElapsedSeconds(_ seconds: Int) -> String {
    let safeSeconds = max(0, seconds)
    let minutes = safeSeconds / 60
    let remainingSeconds = safeSeconds % 60
    return "\(minutes):\(String(format: "%02d", remainingSeconds))"
}

private func formatDuration(_ seconds: Int) -> String {
    let safeSeconds = max(0, seconds)
    let minutes = safeSeconds / 60
    let remainingSeconds = safeSeconds % 60
    if minutes <= 0 {
        return "\(remainingSeconds)秒"
    }
    return "\(minutes)分\(remainingSeconds)秒"
}
