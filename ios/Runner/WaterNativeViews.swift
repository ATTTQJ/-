import SwiftUI

struct WaterNativeRoot: View {
    @ObservedObject var store: WaterNativeStore
    @State private var deviceTab = false
    @State private var pendingStart: WaterUIDevice?
    @State private var showStart = false

    var body: some View {
        ZStack {
            WaterBackground(appearance: store.appearance)
            if !store.ready {
                VStack(spacing: 18) { ProgressView().tint(.white); Text("正在恢复用水状态").font(.subheadline).foregroundColor(.white.opacity(0.7)) }
            } else if store.loggedIn {
                dashboard
            } else {
                WaterNativeLogin(store: store)
            }
            if !store.toast.isEmpty {
                VStack {
                    Spacer()
                    Text(store.toast).font(.subheadline).multilineTextAlignment(.center)
                        .padding(16).frame(maxWidth: 340).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.bottom, 106)
                }.padding(.horizontal, 24).allowsHitTesting(false).transition(.opacity)
            }
        }
        .foregroundColor(.white).preferredColorScheme(.dark)
        .sheet(item: $store.sheet, onDismiss: store.sheetDidDismiss) { sheet in
            WaterNativeSheet(store: store, sheet: sheet)
        }
        .alert(item: Binding(get: { store.sheet == nil ? store.message : nil }, set: { store.message = $0 })) { message in
            Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("知道了")))
        }
        .confirmationDialog("开启\(pendingStart?.name ?? "设备")", isPresented: $showStart, titleVisibility: .visible) {
            Button("确认开始用水") { if let device = pendingStart { store.begin(device) } }
            Button("取消", role: .cancel) {}
        } message: {
            Text((Double(store.balance) ?? 0) < 5 ? "余额不足 5 元，请留意剩余费用，并确认你已到达设备旁。" : "请确认已到达设备旁。热水供应以学校开放时段为准。")
        }
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        circle("clock.arrow.circlepath", label: "历史账单") { store.sheet = .history }
                        Spacer()
                        circle("slider.horizontal.3", label: "外观设置") { store.sheet = .appearance }
                    }.padding(.top, 8)
                    Text(deviceTab ? "设备" : "用水").font(.system(size: 32, weight: .bold)).padding(.top, 1)
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(location).lineLimit(1)
                        Spacer()
                        Button { store.perform("refresh") } label: { Image(systemName: "arrow.clockwise").frame(width: 32, height: 32) }
                            .disabled(store.busy).accessibilityLabel("同步余额、设备与账单")
                    }.font(.subheadline).foregroundColor(.white.opacity(0.62)).padding(.top, -12)
                    if !deviceTab {
                        summary
                        actionCard
                    }
                    HStack {
                        Text(deviceTab ? "我的设备" : "常用设备").font(.headline)
                        Spacer()
                        Button { store.sheet = .manage } label: { Label("管理", systemImage: "slider.horizontal.3").font(.subheadline) }.foregroundColor(.white.opacity(0.66))
                    }.padding(.top, 3)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible())], spacing: 20) {
                        ForEach(Array(store.devices.enumerated()), id: \.element.id) { index, device in
                            WaterNativeDeviceCard(store: store, device: device, index: index)
                        }
                        if store.devices.isEmpty {
                            addCard
                            addCard
                        }
                    }
                    Button { store.sheet = .addDevice } label: {
                        HStack { Image(systemName: "plus"); Text("添加设备"); Spacer(); Text("扫码或按位置查找").font(.caption); Image(systemName: "chevron.right").font(.caption) }
                            .font(.subheadline).foregroundColor(.white.opacity(0.72)).padding(.vertical, 8)
                    }
                    if !deviceTab {
                        HStack { Text("最近用水").font(.headline); Spacer(); Button("全部账单") { store.sheet = .history }.font(.subheadline).foregroundColor(.white.opacity(0.65)) }
                        if store.recent.isEmpty {
                            Text("用水结束后，时长与费用会保存在这里。").font(.subheadline).foregroundColor(.white.opacity(0.62)).padding(.vertical, 10)
                        } else {
                            VStack(spacing: 0) { ForEach(store.recent) { WaterNativeRecordRow(record: $0) } }
                                .padding(.horizontal, 18).waterGlass(store.appearance, radius: 30)
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }
            .refreshable { store.perform("refresh") }
            navigation
        }
    }

    private var location: String {
        let values = ["campus", "building", "room"].compactMap { store.profile[$0] as? String }.filter { !$0.isEmpty }
        return values.isEmpty ? "校园用水 · 随时掌控" : values.joined(separator: " · ")
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 20) {
            WaterNativeMetric(appearance: store.appearance, symbol: "creditcard.fill", tint: store.appearance.iconColor(0), title: "我的余额", value: "¥\(store.balance)", detail: (Double(store.balance) ?? 0) < 5 ? "余额偏低，请及时留意" : "账户余额", footer: "轻点同步余额") { store.perform("refresh") }
            WaterNativeMetric(appearance: store.appearance, symbol: "timer", tint: store.appearance.iconColor(1), title: store.running ? "本次用水" : "今日累计", value: store.durationValue, detail: store.running ? (store.selectedDevice?.name ?? "正在用水") : "今日使用 \(store.todayCount) 次", footer: store.running ? "离开前，记得关水" : store.lastDuration.isEmpty ? "开启设备后自动计时" : "上次 \(store.lastDuration)") { store.sheet = .history }
        }
    }

    private var actionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.running ? "water.waves" : "drop.fill").font(.system(size: 25)).foregroundColor(store.appearance.highlight)
            VStack(alignment: .leading, spacing: 5) {
                Text(store.running ? "正在用水" : "准备就绪").font(.caption).foregroundColor(.white.opacity(0.6))
                Text(store.selectedDevice?.name ?? "先添加一台设备").font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            Spacer(minLength: 3)
            Button {
                if store.running { store.perform("stop") }
                else if let device = store.selectedDevice { pendingStart = device; showStart = true }
            } label: {
                HStack(spacing: 6) { Image(systemName: store.running ? "stop.fill" : "power"); Text(store.running ? "结束用水" : "开始用水") }
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44)
                    .background((store.running ? Color.red : store.appearance.highlight).opacity(0.9), in: Capsule())
                    .foregroundColor((store.running ? Color.red : store.appearance.highlight).readableForeground)
            }.disabled((store.running ? store.waterBusy : store.busy) || store.selectedDevice == nil)
        }.padding(16).waterGlass(store.appearance, radius: 32)
    }

    private var addCard: some View {
        Button { store.sheet = .addDevice } label: {
            VStack(alignment: .leading, spacing: 18) { Image(systemName: "plus").font(.system(size: 28)); Spacer(); Text("添加设备").font(.headline); Text("把常用设备放在这里").font(.caption).foregroundColor(.white.opacity(0.55)) }
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading).padding(18).waterGlass(store.appearance)
        }.buttonStyle(.plain)
    }

    private var navigation: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                tab("用水", symbol: "drop.fill", selected: !deviceTab) { deviceTab = false }
                tab("设备", symbol: "square.grid.2x2.fill", selected: deviceTab) { deviceTab = true }
            }.padding(5).waterGlass(store.appearance, radius: 40).frame(maxWidth: 230)
            Spacer(minLength: 0)
            circle("person.crop.circle.fill", label: "个人账户", size: 62) { store.sheet = .profile }
        }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
    }

    private func tab(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) { Image(systemName: symbol).font(.system(size: 23, weight: .semibold)); Text(title).font(.caption.weight(.semibold)) }
                .foregroundColor(selected ? store.appearance.highlight : .white)
                .frame(maxWidth: .infinity).frame(minHeight: 51)
                .background(selected ? Color.black.opacity(0.35) : .clear, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func circle(_ symbol: String, label: String, size: CGFloat = 46, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: size == 62 ? 28 : 21, weight: .semibold)).frame(width: size, height: size).waterGlass(store.appearance, radius: size / 2) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct WaterNativeMetric: View {
    @ObservedObject var appearance: WaterAppearance
    let symbol: String
    let tint: Color
    let title: String
    let value: String
    let detail: String
    let footer: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 168
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol).font(.system(size: 29, weight: .semibold)).foregroundColor(tint)
                Text(title).font(.subheadline.weight(.medium)).foregroundColor(.white.opacity(0.6))
                Text(value).font(.system(size: 24, weight: .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: 0)
                Text(detail).font(.caption).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                Text(footer).font(.caption2).foregroundColor(.white.opacity(0.5)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18).frame(height: height).waterGlass(appearance)
        }.buttonStyle(.plain)
    }
}

struct WaterNativeDeviceCard: View {
    @ObservedObject var store: WaterNativeStore
    let device: WaterUIDevice
    let index: Int
    @State private var rename = false
    @State private var delete = false
    @State private var name = ""
    @State private var expanded = false
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 172
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: device.symbol).font(.system(size: 29, weight: .semibold)).foregroundColor(store.appearance.iconColor(index + 1))
                Spacer()
                Menu {
                    Button { name = device.name; rename = true } label: { Label("修改备注", systemImage: "pencil") }
                    Button { store.perform("default", ["id": device.id]) { if case .success = $0 { store.showToast("已设为快捷指令默认设备") } } } label: { Label("设为快捷指令默认设备", systemImage: "bolt.fill") }
                    Button { expanded.toggle() } label: { Label("使用统计", systemImage: "chart.bar.fill") }
                    Button { store.sheet = .manage } label: { Label("调整排序", systemImage: "arrow.up.arrow.down") }
                    Button("删除设备", role: .destructive) { delete = true }
                } label: { Image(systemName: "ellipsis").font(.system(size: 18)).foregroundColor(.white.opacity(0.65)).frame(width: 32, height: 32) }
                    .accessibilityLabel("管理\(device.name)")
            }
            Button { store.perform("select", ["id": device.id]); expanded.toggle() } label: {
                VStack(alignment: .leading, spacing: 9) {
                    Text(device.kind).font(.caption).foregroundColor(.white.opacity(0.55))
                    Text(device.name).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 10)
                    HStack {
                        Text(store.running && store.activeId == device.id ? "用水中" : "本月 \(device.currentMonthCount) 次").font(.caption)
                        Spacer(minLength: 2)
                        if store.defaultId == device.id { Image(systemName: "bolt.fill").font(.caption2) }
                        if store.selectedId == device.id { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(store.appearance.highlight) }
                    }.foregroundColor(.white.opacity(0.66))
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded || store.expandedStats {
                Divider().overlay(.white.opacity(0.12))
                Text("累计使用 \(device.count) 次").font(.caption).foregroundColor(.white.opacity(0.7))
                ForEach(device.monthly.keys.sorted().suffix(6), id: \.self) { month in
                    HStack { Text(month); Spacer(); Text("\(device.monthly[month] ?? 0) 次") }.font(.caption2).foregroundColor(.white.opacity(0.55))
                }
            }
        }.padding(18).frame(minHeight: height, alignment: .topLeading)
            .waterGlass(store.appearance, selected: store.selectedId == device.id)
            .sheet(isPresented: $rename) {
                NavigationView {
                    Form { TextField("设备名称", text: $name) }
                        .navigationTitle("修改设备备注")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("取消") { rename = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("保存") { store.perform("rename", ["id": device.id, "value": name]) { if case .success = $0 { rename = false } } }
                            }
                        }
                }.navigationViewStyle(.stack).preferredColorScheme(.dark)
            }
            .alert("删除\(device.name)？", isPresented: $delete) {
                Button("删除设备", role: .destructive) { store.perform("delete", ["id": device.id]) }
                Button("取消", role: .cancel) {}
            } message: { Text("设备会从常用列表移除，历史账单会保留。") }
    }
}

struct WaterNativeRecordRow: View {
    let record: WaterUIRecord
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title3)
            VStack(alignment: .leading, spacing: 6) {
                Text(record.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("− ¥\(record.amount, specifier: "%.2f")").font(.subheadline.weight(.semibold))
                Text(record.duration).font(.caption).foregroundColor(.white.opacity(0.55))
            }
        }.padding(.vertical, 16)
    }
}

struct WaterNativeSheet: View {
    @ObservedObject var store: WaterNativeStore
    let sheet: WaterUISheet
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ZStack {
                WaterBackground(appearance: store.appearance)
                Color.black.opacity(0.35).ignoresSafeArea()
                content
            }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }.navigationViewStyle(.stack).preferredColorScheme(.dark).tint(store.appearance.highlight)
            .alert(item: $store.message) { message in
                Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("知道了")))
            }
    }
    private var title: String {
        switch sheet {
        case .appearance: return "外观与配色"
        case .profile: return "我的账户"
        case .history: return "用水账单"
        case .addDevice: return "添加设备"
        case .manage: return "管理设备"
        case .scanner: return "扫描设备二维码"
        }
    }
    @ViewBuilder private var content: some View {
        switch sheet {
        case .appearance: WaterNativeAppearanceView(store: store, appearance: store.appearance)
        case .profile: WaterNativeProfile(store: store)
        case .history: WaterNativeHistory(store: store)
        case .addDevice: WaterNativeAddDevice(store: store)
        case .manage: WaterNativeManage(store: store)
        case .scanner: WaterQRScanner { code in
            store.perform("scan", ["code": code]) { result in
                if case .success = result { store.sheet = nil; store.showToast("设备绑定成功") }
            }
        }
        }
    }
}

struct WaterNativeLogin: View {
    @ObservedObject var store: WaterNativeStore
    @State private var phone = ""
    @State private var code = ""
    @State private var countdown = 0
    @State private var sending = false
    @State private var loggingIn = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Spacer(); Button { store.sheet = .appearance } label: { Image(systemName: "slider.horizontal.3").frame(width: 46, height: 46).waterGlass(store.appearance, radius: 23) } }
                Spacer(minLength: 80)
                Image(systemName: "drop.fill").font(.system(size: 43)).foregroundColor(store.appearance.highlight)
                Text("UY Water").font(.system(size: 34, weight: .bold))
                Text("登录，让每一次用水更自在。").font(.subheadline).foregroundColor(.white.opacity(0.65))
                VStack(spacing: 18) {
                    TextField("手机号", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber).padding(15).background(.white.opacity(0.08), in: Capsule())
                    HStack {
                        TextField("验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).padding(15).background(.white.opacity(0.08), in: Capsule())
                        Button(countdown > 0 ? "\(countdown)s" : "发送验证码") {
                            guard phone.count == 11 else { store.showToast("请输入 11 位手机号"); return }
                            sending = true
                            store.perform("sendCode", ["phone": phone]) { result in sending = false; if case .success = result { countdown = 60 } }
                        }.font(.subheadline).disabled(countdown > 0 || sending || store.busy)
                    }
                    Button {
                        guard !code.isEmpty else { store.showToast("请输入验证码"); return }
                        loggingIn = true
                        store.perform("login", ["phone": phone, "code": code]) { _ in loggingIn = false }
                    } label: { Text(loggingIn ? "登录中…" : "登录").font(.headline).frame(maxWidth: .infinity).padding(15).background(store.appearance.highlight, in: Capsule()).foregroundColor(store.appearance.highlight.readableForeground) }
                        .disabled(loggingIn || store.busy)
                }.padding(22).waterGlass(store.appearance)
            }.padding(22)
        }.onReceive(timer) { _ in if countdown > 0 { countdown -= 1 } }
    }
}

struct WaterNativeHistory: View {
    @ObservedObject var store: WaterNativeStore
    @State private var clear = false
    private var months: [Int] { Array(1...(store.historyYear == Calendar.current.component(.year, from: Date()) ? Calendar.current.component(.month, from: Date()) : 12)) }
    private var total: Double { store.records.reduce(0) { $0 + $1.amount } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Picker("年份", selection: Binding(get: { store.historyYear }, set: { request(year: $0, month: min(store.historyMonth, $0 == Calendar.current.component(.year, from: Date()) ? Calendar.current.component(.month, from: Date()) : 12)) })) {
                        ForEach(store.historyYears, id: \.self) { Text("\($0)年").tag($0) }
                    }
                    Picker("月份", selection: Binding(get: { store.historyMonth }, set: { request(year: store.historyYear, month: $0) })) { ForEach(months, id: \.self) { Text("\($0)月").tag($0) } }
                    Spacer()
                    Button { request(year: store.historyYear, month: store.historyMonth) } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.accessibilityLabel("同步本月账单")
                }.disabled(store.historyLoading)
                HStack { VStack(alignment: .leading, spacing: 8) { Text("本月支出").foregroundColor(.white.opacity(0.6)); Text("¥\(total, specifier: "%.2f")").font(.largeTitle.bold()) }; Spacer(); Text("\(store.records.count) 次用水").foregroundColor(.white.opacity(0.6)) }.padding(22).waterGlass(store.appearance)
                if store.historyLoading { ProgressView("同步账单与本地时长…").frame(maxWidth: .infinity) }
                if store.records.isEmpty { Text("这个月还没有记录").foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity).padding(35) }
                LazyVStack(spacing: 0) { ForEach(store.records) { WaterNativeRecordRow(record: $0); Divider().opacity(0.15) } }
                Button("清空本地账单缓存", role: .destructive) { clear = true }.font(.subheadline).padding(.top)
            }.padding(20)
        }.alert("清空本地记录？", isPresented: $clear) {
            Button("清空", role: .destructive) { store.perform("clearHistory") }
            Button("取消", role: .cancel) {}
        } message: { Text("将清除本地账单缓存与时长补丁，服务器账单不受影响。") }
    }
    private func request(year: Int, month: Int) { store.perform("history", ["year": year, "month": month]) }
}

struct WaterNativeManage: View {
    @ObservedObject var store: WaterNativeStore
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Toggle("始终展开设备统计", isOn: Binding(get: { store.expandedStats }, set: { store.perform("expandedStats", ["value": $0]) })).font(.subheadline).padding(18).waterGlass(store.appearance, radius: 28)
                ForEach(Array(store.devices.enumerated()), id: \.element.id) { index, device in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(device.name).font(.headline)
                        HStack {
                            Button { store.perform("move", ["id": device.id, "index": index - 1]) } label: { Label("上移", systemImage: "arrow.up").font(.caption).frame(minHeight: 44) }.disabled(index == 0 || store.busy)
                            Spacer()
                            Button { store.perform("move", ["id": device.id, "index": index + 1]) } label: { Label("下移", systemImage: "arrow.down").font(.caption).frame(minHeight: 44) }.disabled(index == store.devices.count - 1 || store.busy)
                        }
                        Button { store.perform("default", ["id": device.id]) } label: { Label(store.defaultId == device.id ? "快捷指令默认设备" : "设为快捷指令默认设备", systemImage: "bolt.fill").font(.caption) }
                    }.padding(20).waterGlass(store.appearance, radius: 30)
                }
                Button("添加设备") { store.sheet = .addDevice }.padding()
            }.padding(20)
        }
    }
}

struct WaterNativeProfile: View {
    @ObservedObject var store: WaterNativeStore
    @State private var logout = false
    @Environment(\.dismiss) private var dismiss
    private func value(_ key: String) -> String { let text = store.profile[key] as? String ?? ""; return text.isEmpty ? "未提供" : text }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button {
                    // The existing avatar workflow presents native image picker /
                    // cropper controllers from Flutter. Dismiss this sheet first.
                    store.pickAvatarAfterDismiss = true
                    dismiss()
                } label: {
                    VStack(spacing: 12) {
                        if let url = URL(string: store.profile["avatar"] as? String ?? ""), !url.absoluteString.isEmpty {
                            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.crop.circle.fill").resizable() }.frame(width: 76, height: 76).clipShape(Circle())
                        } else { Image(systemName: "person.crop.circle.fill").font(.system(size: 76)) }
                        Text(value("name") == "User" ? "同学" : value("name")).font(.title2.bold())
                        Text(value("phone")).font(.subheadline).foregroundColor(.white.opacity(0.6))
                        Text("轻点头像更换与裁剪").font(.caption).foregroundColor(.white.opacity(0.45))
                    }
                }.buttonStyle(.plain).padding(.vertical, 14)
                VStack(spacing: 0) {
                    profileRow("学校", value("school")); profileRow("校区", value("campus"))
                    profileRow("楼栋", value("building")); profileRow("楼层 / 房间", value("room"))
                    profileRow("地址", value("address")); profileRow("学号", value("studentNo"))
                    profileRow("年级", value("grade")); profileRow("实名认证", store.profile["realName"] as? Bool == true ? "已实名" : "未实名")
                }.padding(20).waterGlass(store.appearance)
                VStack(alignment: .leading, spacing: 12) {
                    Label("快捷指令与灵动岛", systemImage: "bolt.fill").font(.headline)
                    Text("默认设备：\(store.devices.first(where: { $0.id == store.defaultId })?.name ?? "未设置")").font(.subheadline)
                    Text("在设备菜单中设置默认设备，即可通过快捷指令开关水；用水状态会与实时活动自动同步。").font(.caption).foregroundColor(.white.opacity(0.6))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).waterGlass(store.appearance)
                Button("退出登录", role: .destructive) { logout = true }.padding()
            }.padding(20)
        }.alert("退出当前账户？", isPresented: $logout) {
            Button("退出登录", role: .destructive) { store.perform("logout") }
            Button("取消", role: .cancel) {}
        }
    }
    private func profileRow(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top) { Text(title).foregroundColor(.white.opacity(0.5)); Spacer(); Text(text).multilineTextAlignment(.trailing) }.font(.subheadline).padding(.vertical, 12)
    }
}

struct WaterNativeAppearanceView: View {
    @ObservedObject var store: WaterNativeStore
    @ObservedObject var appearance: WaterAppearance
    @State private var photoPicker = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("背景").font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(Array(WaterAppearance.presets.enumerated()), id: \.offset) { _, preset in
                        Button { appearance.removeWallpaper(); appearance.background = Color(argb: preset.1); if appearance.monet { store.palette(seed: preset.1) } } label: {
                            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(argb: preset.1)).frame(height: 40).overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(appearance.background.argb == preset.1 && appearance.wallpaper == nil ? 0.9 : 0.2), lineWidth: 1.5))
                        }.accessibilityLabel(preset.0)
                    }
                }
                ColorPicker("自定义纯色", selection: $appearance.background, supportsOpacity: false)
                    .onChange(of: appearance.background) { _ in if appearance.monet { store.palette(seed: appearance.background.argb) } }
                Button { photoPicker = true } label: { Label("从相册选择背景", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity).padding(16).waterGlass(appearance, radius: 26) }
                if appearance.wallpaper != nil { Button("移除自定义图片") { appearance.removeWallpaper(); if appearance.monet { store.palette(seed: appearance.background.argb) } }.font(.subheadline) }
                Divider().opacity(0.2)
                Toggle("莫奈配色 · 跟随背景", isOn: $appearance.monet).onChange(of: appearance.monet) { enabled in
                    guard enabled else { return }
                    if let image = appearance.wallpaper?.jpegData(compressionQuality: 0.6) { store.palette(image: image) } else { store.palette(seed: appearance.background.argb) }
                }
                Text("从背景提取 Material 配色，让卡片、图标和强调色保持协调。").font(.caption).foregroundColor(.white.opacity(0.55))
                ColorPicker("自定义强调色", selection: $appearance.accent, supportsOpacity: false).onChange(of: appearance.accent) { _ in appearance.monet = false }
                VStack(alignment: .leading, spacing: 10) { HStack { Text("玻璃浓度"); Spacer(); Text("\(Int(appearance.density * 100))%").foregroundColor(.white.opacity(0.55)) }; Slider(value: $appearance.density, in: 0.02...0.45) }.font(.subheadline)
                VStack(alignment: .leading, spacing: 10) { HStack { Text("边缘亮度"); Spacer(); Text("\(Int(appearance.refraction * 100))%").foregroundColor(.white.opacity(0.55)) }; Slider(value: $appearance.refraction, in: 0...1) }.font(.subheadline)
                Button("恢复默认外观") { appearance.reset() }.frame(maxWidth: .infinity).padding(.vertical)
            }.padding(22)
        }.sheet(isPresented: $photoPicker) {
            WaterWallpaperPicker { image in
                do { let data = try appearance.setWallpaper(image); if appearance.monet { store.palette(image: data) } }
                catch { store.message = WaterUIMessage(title: "背景未保存", text: error.localizedDescription) }
            }
        }
    }
}

struct WaterNativeAddDevice: View {
    @ObservedObject var store: WaterNativeStore
    @State private var step = 0
    @State private var way = ""
    @State private var options: [WaterUIOption] = []
    @State private var previous: [[WaterUIOption]] = []
    @State private var loading = false
    @State private var requestError = ""
    @State private var parentId = "27720"
    @State private var parents: [String] = []
    private let titles = ["选择用水类型", "选择校区", "选择楼栋", "选择楼层", "选择寝室 / 设备"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { store.sheet = .scanner } label: { Label("扫描设备二维码", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity).padding(18).waterGlass(store.appearance, radius: 28) }
                HStack { if step > 0 { Button { step -= 1; options = previous.removeLast(); parentId = parents.removeLast() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) } }; Text(titles[step]).font(.headline) }
                if loading { ProgressView().frame(maxWidth: .infinity).padding(30) }
                if !requestError.isEmpty { Text(requestError).font(.subheadline).foregroundColor(.white.opacity(0.6)); Button("重试") { fetch() } }
                if options.isEmpty && !loading && requestError.isEmpty { Text("暂无可用选项，请刷新后重试。").font(.subheadline).foregroundColor(.white.opacity(0.6)); Button("刷新") { fetch() } }
                ForEach(options) { option in
                    Button { select(option) } label: { HStack { Text(option.name); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(20).waterGlass(store.appearance, radius: 25) }.disabled(loading)
                }
            }.padding(20)
        }.onAppear { if options.isEmpty { fetch() } }
    }
    private func fetch() {
        loading = true; requestError = ""
        store.perform("locations", ["step": step, "id": parentId]) { result in
            loading = false
            switch result {
            case .success(let value): options = (value as? [[String: String]] ?? []).map { WaterUIOption(id: $0["id"] ?? "", name: $0["name"] ?? "") }
            case .failure(let error): requestError = error.localizedDescription
            }
        }
    }
    private func select(_ option: WaterUIOption) {
        if step == 0 { way = option.id }
        if step < 4 {
            previous.append(options); parents.append(parentId); step += 1
            parentId = step == 1 ? "27720" : option.id; options = []; fetch()
        } else {
            loading = true
            store.perform("bind", ["id": option.id, "way": way]) { result in
                loading = false
                if case .success = result { store.sheet = nil; store.showToast("设备绑定成功") }
            }
        }
    }
}
