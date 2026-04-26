import ActivityKit
import Foundation

@available(iOS 16.1, *)
enum WaterLiveActivityController {
    static func start(session: WaterIntentSession) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        await endMatching(orderNum: "")

        let attributes = WaterLiveActivityAttributes(
            deviceId: session.deviceId,
            deviceName: session.deviceName,
            orderNum: session.orderNum,
            isHotWater: session.isHotWater
        )
        let state = WaterLiveActivityAttributes.ContentState(
            statusText: "用水中",
            startedAt: session.startedAt,
            elapsedSeconds: 0,
            amountText: "",
            isRunning: true
        )

        if #available(iOS 16.2, *) {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } else {
            _ = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
        }
    }

    static func updateRunning(orderNum: String, startedAt: Date, elapsedSeconds: Int) async {
        guard let activity = activity(orderNum: orderNum) else {
            return
        }
        let state = WaterLiveActivityAttributes.ContentState(
            statusText: "用水中",
            startedAt: startedAt,
            elapsedSeconds: elapsedSeconds,
            amountText: activity.contentState.amountText,
            isRunning: true
        )
        await update(activity: activity, state: state)
    }

    static func finish(session: WaterIntentSession, settlement: WaterSettlement) async {
        let targets = matchingActivities(orderNum: session.orderNum)
        let activities = targets.isEmpty ? Activity<WaterLiveActivityAttributes>.activities : targets
        let state = WaterLiveActivityAttributes.ContentState(
            statusText: "已关水",
            startedAt: session.startedAt,
            elapsedSeconds: settlement.elapsedSeconds,
            amountText: settlement.amountText,
            isRunning: false
        )

        for activity in activities {
            await update(activity: activity, state: state)
        }

        try? await Task.sleep(nanoseconds: 15_000_000_000)

        for activity in activities {
            if #available(iOS 16.2, *) {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(using: state, dismissalPolicy: .immediate)
            }
        }
    }

    static func endMatching(orderNum: String) async {
        let targets = matchingActivities(orderNum: orderNum)
        let activities = targets.isEmpty ? Activity<WaterLiveActivityAttributes>.activities : targets

        for activity in activities {
            let elapsedSeconds = max(
                activity.contentState.elapsedSeconds,
                Int(Date().timeIntervalSince(activity.contentState.startedAt))
            )
            let state = WaterLiveActivityAttributes.ContentState(
                statusText: "已关水",
                startedAt: activity.contentState.startedAt,
                elapsedSeconds: elapsedSeconds,
                amountText: activity.contentState.amountText,
                isRunning: false
            )
            if #available(iOS 16.2, *) {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(using: state, dismissalPolicy: .immediate)
            }
        }
    }

    private static func update(
        activity: Activity<WaterLiveActivityAttributes>,
        state: WaterLiveActivityAttributes.ContentState
    ) async {
        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
            await activity.update(using: state)
        }
    }

    private static func activity(orderNum: String) -> Activity<WaterLiveActivityAttributes>? {
        matchingActivities(orderNum: orderNum).first
    }

    private static func matchingActivities(orderNum: String) -> [Activity<WaterLiveActivityAttributes>] {
        Activity<WaterLiveActivityAttributes>.activities.filter { activity in
            orderNum.isEmpty || activity.attributes.orderNum == orderNum
        }
    }
}
