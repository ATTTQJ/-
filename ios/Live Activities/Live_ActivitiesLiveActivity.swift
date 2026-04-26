import ActivityKit
import Foundation
import WidgetKit
import SwiftUI

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
                Image(systemName: context.state.isRunning ? "drop.fill" : "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(context.state.isRunning ? Color.cyan : Color.green)
                    .frame(width: 34, height: 28, alignment: .center)
            } compactTrailing: {
                WaterLiveTimerText(state: context.state)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: 54, height: 28, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isRunning ? "drop.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(context.state.isRunning ? Color.cyan : Color.green)
            }
            .keylineTint(context.state.isRunning ? Color.cyan : Color.green)
        }
    }
}

private struct WaterLockScreenView: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            WaterStatusIcon(isRunning: context.state.isRunning, size: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.isRunning ? "用水中" : "已关水")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(context.attributes.deviceName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                WaterLiveTimerText(state: context.state)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            if !context.state.isRunning {
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
        HStack(spacing: 10) {
            WaterStatusIcon(isRunning: context.state.isRunning, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isRunning ? "用水中" : "已关水")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.attributes.deviceName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: 190, alignment: .leading)
    }
}

private struct WaterIslandTrailingAction: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if context.state.isRunning {
                Spacer(minLength: 22)
                Link(destination: URL(string: "waterapp://stop")!) {
                    Text("结束")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.56, green: 0.16, blue: 0.14))
                        )
                }
            } else {
                WaterAmountText(state: context.state)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottomTrailing)
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
                WaterLiveTimerText(state: context.state)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if !context.state.isRunning {
                    Text("用水 \(formatDuration(context.state.elapsedSeconds))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }
}

private struct WaterStatusIcon: View {
    let isRunning: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill((isRunning ? Color.cyan : Color.green).opacity(0.18))
            Image(systemName: isRunning ? "drop.fill" : "checkmark")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(isRunning ? Color.cyan : Color.green)
        }
        .frame(width: size, height: size)
    }
}

private struct WaterAmountText: View {
    let state: WaterLiveActivityAttributes.ContentState

    var body: some View {
        Text(state.amountText.isEmpty ? "已完成" : state.amountText)
            .font(.system(size: state.amountText.isEmpty ? 17 : 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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

private func formatDuration(_ seconds: Int) -> String {
    let safeSeconds = max(0, seconds)
    let minutes = safeSeconds / 60
    let remainingSeconds = safeSeconds % 60
    if minutes <= 0 {
        return "\(remainingSeconds)秒"
    }
    return "\(minutes)分\(remainingSeconds)秒"
}
