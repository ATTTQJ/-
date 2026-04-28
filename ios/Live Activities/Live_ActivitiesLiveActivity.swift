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
                DynamicIslandExpandedRegion(.bottom) {
                    WaterIslandExpandedContent(context: context)
                }
            } compactLeading: {
                WaterCompactIcon(context: context)
            } compactTrailing: {
                if context.state.isRunning {
                    WaterLiveTimerText(state: context.state)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 52, height: 28, alignment: .trailing)
                } else {
                    Text(context.state.amountText.isEmpty ? "¥0.00" : context.state.amountText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 58, height: 28, alignment: .trailing)
                }
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
                    .truncationMode(.tail)

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
                WaterStopButton(state: context.state)
            } else {
                WaterAmountText(state: context.state)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct WaterIslandExpandedContent: View {
    let context: ActivityViewContext<WaterLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                WaterStatusIcon(context: context, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.statusText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(context.attributes.deviceName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if context.state.isRunning {
                HStack(alignment: .bottom, spacing: 12) {
                    WaterElapsedBlock(state: context.state)

                    Spacer(minLength: 8)

                    WaterStopButton(state: context.state)
                        .padding(.bottom, 2)
                }
            } else {
                WaterFinishedBlock(state: context.state)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }
}

private struct WaterElapsedBlock: View {
    let state: WaterLiveActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("已使用")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            WaterLiveTimerText(state: state)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .lineLimit(1)
    }
}

private struct WaterFinishedBlock: View {
    let state: WaterLiveActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("用水时长")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                Text(formatDuration(state.elapsedSeconds))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: 122, alignment: .leading)

            Spacer(minLength: 16)

            WaterAmountPill(state: state)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.top, 1)
        .padding(.bottom, 7)
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
    let state: WaterLiveActivityAttributes.ContentState
    private var isStopping: Bool {
        state.statusText == "关水中"
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: StopWaterIntent()) {
                Group {
                    if isStopping {
                        WaterLoadingDots()
                    } else {
                        Text("结束")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 64, height: 38)
                .background(
                    Capsule()
                        .fill(Color(red: 0.58, green: 0.18, blue: 0.16))
                )
            }
            .buttonStyle(.plain)
            .disabled(isStopping)
        }
    }
}

private struct WaterLoadingDots: View {
    private let interval: TimeInterval = 0.32

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { timeline in
            let activeIndex = Int(timeline.date.timeIntervalSinceReferenceDate / interval) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index == activeIndex ? 1 : 0.36))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 34, height: 18)
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
            .font(.system(size: state.amountText.isEmpty ? 17 : 30, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }
}

private struct WaterAmountPill: View {
    let state: WaterLiveActivityAttributes.ContentState
    private let pillWidth: CGFloat = 96

    var body: some View {
        Text(state.amountText.isEmpty ? "¥0.00" : state.amountText)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.96))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .multilineTextAlignment(.center)
            .frame(width: pillWidth - 16, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.13, green: 0.84, blue: 0.78).opacity(0.15))
            )
            .frame(width: pillWidth, alignment: .trailing)
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
