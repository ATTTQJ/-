import CryptoKit
import Foundation

struct WaterApiClient {
    private static let domain = "uyschool.uyxy.xin"
    private static let salt = "e275f1af-1dda-4b47-9d87-afcbe1f96dca"
    private static let versionName = "V2.9.2"
    private static let versionCode = "92"

    let auth: WaterAuthContext

    func startWater(device: WaterIntentDevice) async throws -> WaterIntentSession {
        guard auth.isValid else {
            throw WaterIntentError.missingAuth
        }

        let baseParams: [(String, String)] = [
            ("orderWay", "1"),
            ("theConnectionMethod", "2"),
            ("deviceInfId", device.id),
            ("billType", "\(device.billType)"),
            ("lackBalance", "lackBalance")
        ]

        _ = try await post(
            path: "device/useEquipment",
            params: baseParams + [("type", "1")]
        )

        try? await Task.sleep(nanoseconds: 550_000_000)

        let response = try await post(
            path: "device/useEquipment",
            params: baseParams + [("type", "0")]
        )
        try ensureSuccess(response)

        guard let data = response["data"] as? [String: Any] else {
            throw WaterIntentError.invalidServerResponse
        }

        let orderNum = stringValue(data["orderNum"])
        let tableName = stringValue(data["tableName"])
        let mac = stringValue(data["mac"])
        guard !orderNum.isEmpty else {
            throw WaterIntentError.invalidServerResponse
        }

        return WaterIntentSession(
            orderNum: orderNum,
            tableName: tableName,
            mac: mac,
            deviceId: device.id,
            deviceName: device.name.isEmpty ? "当前设备" : device.name,
            isHotWater: device.isHotWater,
            startedAtMs: nowMillis(),
            initialBalance: auth.balance,
            isRunning: true
        )
    }

    func stopWater(session: WaterIntentSession) async throws -> WaterSettlement {
        guard auth.isValid else {
            throw WaterIntentError.missingAuth
        }

        let response = try await post(
            path: "device/endEquipment",
            params: [
                ("orderNum", session.orderNum),
                ("mac", session.mac),
                ("tableName", session.tableName)
            ]
        )
        try ensureSuccess(response)

        let syncedBalance = try? await fetchBalance()
        let amount = extractSettlementAmount(from: response)
            ?? balanceDiff(initial: session.initialBalance, current: syncedBalance ?? auth.balance)
            ?? 0
        let elapsedSeconds = extractDurationSeconds(from: response)
            ?? session.elapsedSeconds

        return WaterSettlement(amount: max(0, amount), elapsedSeconds: max(0, elapsedSeconds))
    }

    func fetchBalance() async throws -> String {
        let response = try await post(path: "user/queryUserWalletInfo", params: [])
        try ensureSuccess(response)
        if let data = response["data"] as? [String: Any] {
            return stringValue(data["uBalance"])
        }
        return ""
    }

    private func post(path: String, params: [(String, String)]) async throws -> [String: Any] {
        let timestamp = "\(nowMillis())"
        let sign = generateSign(timestamp: timestamp, params: params)
        let bodyPairs = params + [
            ("userId", auth.userId),
            ("token", auth.token),
            ("AndroidVersionName", Self.versionName),
            ("AndroidVersionCode", Self.versionCode),
            ("sign", sign),
            ("dateTime", timestamp)
        ]
        let body = bodyPairs
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "\(urlEncode($0.0))=\(urlEncode($0.1))" }
            .joined(separator: "&")
        let bodyData = Data(body.utf8)

        guard let url = URL(string: "https://\(Self.domain)/ue/app/\(path)") else {
            throw WaterIntentError.invalidServerResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.timeoutInterval = 12
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        request.setValue("\(bodyData.count)", forHTTPHeaderField: "content-length")
        request.setValue("okhttp/4.9.0", forHTTPHeaderField: "user-agent")
        request.setValue("gzip", forHTTPHeaderField: "accept-encoding")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw WaterIntentError.server("网络请求失败：\(httpResponse.statusCode)")
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            throw WaterIntentError.invalidServerResponse
        }
        return json
    }

    private func generateSign(timestamp: String, params: [(String, String)]) -> String {
        var signParams: [String: String] = [
            "AndroidVersionName": Self.versionName,
            "AndroidVersionCode": Self.versionCode,
            "dateTime": timestamp
        ]
        for (key, value) in params {
            signParams[key] = value
        }
        signParams["userId"] = auth.userId
        signParams["token"] = auth.token
        signParams = signParams.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let raw = signParams.keys
            .sorted { $0.lowercased() < $1.lowercased() }
            .map { "\($0)=\(signParams[$0] ?? "")" }
            .joined(separator: "&") +
            (auth.token.isEmpty ? "&\(timestamp)" : "&\(auth.token)") +
            "&\(Self.salt)&292"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func ensureSuccess(_ response: [String: Any]) throws {
        let code = stringValue(response["code"])
        if code == "0" || code == "200" {
            return
        }
        throw WaterIntentError.server(stringValue(response["msg"]))
    }

    private func extractSettlementAmount(from response: [String: Any]) -> Double? {
        firstMatchingValue(
            in: response,
            keys: [
                "expAmount",
                "expAmountStr",
                "cost",
                "costStr",
                "amount",
                "amountStr",
                "money",
                "fee",
                "feeStr",
                "deductAmount",
                "deductAmountStr",
                "consumeAmount",
                "payAmount"
            ]
        ).flatMap(parseMoney)
    }

    private func extractDurationSeconds(from response: [String: Any]) -> Int? {
        if let value = firstMatchingValue(
            in: response,
            keys: [
                "durationSeconds",
                "useSeconds",
                "useSecond",
                "timeLength",
                "timeLen",
                "useLong",
                "useTimeLong",
                "duration",
                "useTime",
                "timeStr"
            ]
        ), let parsed = parseDuration(value) {
            return parsed
        }

        let start = firstMatchingValue(
            in: response,
            keys: ["startTime", "beginTime", "beginDate", "openTime", "createTime"]
        ).flatMap(parseDate)
        let end = firstMatchingValue(
            in: response,
            keys: ["endTime", "stopTime", "finishTime", "closeTime", "updateTime"]
        ).flatMap(parseDate)

        if let start, let end {
            let seconds = Int(end.timeIntervalSince(start))
            return seconds >= 0 ? seconds : nil
        }
        return nil
    }

    private func firstMatchingValue(in source: Any, keys: Set<String>) -> Any? {
        if let map = source as? [String: Any] {
            for (key, value) in map where keys.contains(key) {
                return value
            }
            for value in map.values {
                if let match = firstMatchingValue(in: value, keys: keys) {
                    return match
                }
            }
        }
        if let list = source as? [Any] {
            for item in list {
                if let match = firstMatchingValue(in: item, keys: keys) {
                    return match
                }
            }
        }
        return nil
    }

    private func balanceDiff(initial: String, current: String) -> Double? {
        guard let before = Double(initial), let after = Double(current) else {
            return nil
        }
        let diff = before - after
        return diff > 0 ? diff : nil
    }

    private func parseMoney(_ value: Any) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        let filtered = String(describing: value).filter { char in
            char.isNumber || char == "." || char == "-"
        }
        return Double(String(filtered))
    }

    private func parseDuration(_ value: Any) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        let text = String(describing: value)
        if let match = text.firstMatch(pattern: #"(\d{1,2}):(\d{2})"#) {
            let minutes = Int(match[1]) ?? 0
            let seconds = Int(match[2]) ?? 0
            return minutes * 60 + seconds
        }
        if let match = text.firstMatch(pattern: #"(\d+)\s*分\s*(\d+)\s*秒"#) {
            let minutes = Int(match[1]) ?? 0
            let seconds = Int(match[2]) ?? 0
            return minutes * 60 + seconds
        }
        let digits = text.filter(\.isNumber)
        return Int(String(digits))
    }

    private func parseDate(_ value: Any) -> Date? {
        let text = String(describing: value)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "T")
        return ISO8601DateFormatter().date(from: text)
    }

    private func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func stringValue(_ value: Any?) -> String {
        guard let value else {
            return ""
        }
        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private extension String {
    func firstMatch(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: self,
                range: NSRange(startIndex..., in: self)
              ) else {
            return nil
        }

        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else {
                return nil
            }
            return String(self[range])
        }
    }
}
