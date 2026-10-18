import PhotosUI
import SwiftUI
import UIKit

final class WaterAppearance: ObservableObject {
    private enum Keys {
        static let prefix = "water.native.appearance."
        static let background = prefix + "background"
        static let accent = prefix + "accent"
        static let monet = prefix + "monet"
        static let density = prefix + "density"
        static let refraction = prefix + "refraction"
        static let primary = prefix + "primary"
        static let secondary = prefix + "secondary"
        static let tertiary = prefix + "tertiary"
    }
    static let presets: [(String, UInt32)] = [
        ("雾灰", 0xFF74777B), ("石墨", 0xFF30343A), ("午夜", 0xFF202939),
        ("深海", 0xFF29464F), ("松林", 0xFF354A40), ("茄紫", 0xFF4A4055),
        ("可可", 0xFF58443F), ("陶土", 0xFF986F60), ("玫瑰", 0xFFAE8796),
        ("鼠尾草", 0xFF91A69A), ("雾蓝", 0xFF849AB4), ("鸢尾", 0xFF9C94B6),
        ("奶杏", 0xFFD9C8B4), ("燕麦", 0xFFC6C2B0), ("黄油", 0xFFDAD09C),
        ("薄荷", 0xFFA7CCC0), ("冰川", 0xFF9BC4CE), ("月白", 0xFFE1E3E5)
    ]
    @Published var background: Color { didSet { save() } }
    @Published var accent: Color { didSet { save() } }
    @Published var monet: Bool { didSet { save() } }
    @Published var density: Double { didSet { save() } }
    @Published var refraction: Double { didSet { save() } }
    @Published var wallpaper: UIImage?
    @Published private(set) var wallpaperDarkening = 0.18
    @Published var primary: Color { didSet { save() } }
    @Published var secondary: Color { didSet { save() } }
    @Published var tertiary: Color { didSet { save() } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func stored(_ key: String, _ fallback: UInt32) -> Color {
            Color(argb: (defaults.object(forKey: key) as? NSNumber)?.uint32Value ?? fallback)
        }
        background = stored(Keys.background, 0xFF74777B)
        accent = stored(Keys.accent, 0xFF0A9FFF)
        monet = defaults.bool(forKey: Keys.monet)
        density = defaults.object(forKey: Keys.density) == nil ? 0.16 : defaults.double(forKey: Keys.density)
        refraction = defaults.object(forKey: Keys.refraction) == nil ? 0.5 : defaults.double(forKey: Keys.refraction)
        primary = stored(Keys.primary, 0xFF91CDFF)
        secondary = stored(Keys.secondary, 0xFFB7C8DD)
        tertiary = stored(Keys.tertiary, 0xFFD6BDE5)
        if let url = Self.wallpaperURL, let data = try? Data(contentsOf: url) {
            wallpaper = UIImage(data: data)
            if let image = wallpaper { wallpaperDarkening = Self.darkening(image) }
        }
    }

    var highlight: Color { monet ? primary : accent }
    var backgroundDarkening: Double {
        if wallpaper != nil { return wallpaperDarkening }
        return Self.darkening(background.argb)
    }

    private static func darkening(_ argb: UInt32) -> Double {
        let brightness = (Double((argb >> 16) & 255) * 0.2126 + Double((argb >> 8) & 255) * 0.7152 + Double(argb & 255) * 0.0722) / 255
        return brightness > 0.68 ? 0.55 : brightness > 0.48 ? 0.36 : 0.16
    }

    private static func darkening(_ image: UIImage) -> Double {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let sample = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        guard let cg = sample.cgImage, let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data), CFDataGetLength(data) >= 4 else { return 0.24 }
        // UIGraphics uses a premultiplied BGRA surface; only luminance is needed.
        return darkening(0xFF000000 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0]))
    }
    func iconColor(_ index: Int) -> Color {
        if monet { return [primary, secondary, tertiary][index % 3] }
        return [Color(argb: 0xFF32D74B), Color(argb: 0xFF36D3F2), Color(argb: 0xFF7772FF), Color(argb: 0xFFFF9F2B)][index % 4]
    }

    private func save() {
        defaults.set(background.argb, forKey: Keys.background)
        defaults.set(accent.argb, forKey: Keys.accent)
        defaults.set(monet, forKey: Keys.monet)
        defaults.set(density, forKey: Keys.density)
        defaults.set(refraction, forKey: Keys.refraction)
        defaults.set(primary.argb, forKey: Keys.primary)
        defaults.set(secondary.argb, forKey: Keys.secondary)
        defaults.set(tertiary.argb, forKey: Keys.tertiary)
    }

    func applyPalette(_ colors: [String: NSNumber]) {
        if let value = colors["primary"] { primary = Color(argb: value.uint32Value) }
        if let value = colors["secondary"] { secondary = Color(argb: value.uint32Value) }
        if let value = colors["tertiary"] { tertiary = Color(argb: value.uint32Value) }
    }

    private static var wallpaperURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("WaterAppearance", isDirectory: true).appendingPathComponent("wallpaper.jpg")
    }

    func setWallpaper(_ image: UIImage) throws -> Data {
        // Downsample before persistence and palette extraction; avoid keeping a
        // full-resolution camera image resident under every glass surface.
        let scale = min(1, 1800 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.85), let url = Self.wallpaperURL else {
            throw NSError(domain: "WaterAppearance", code: 1, userInfo: [NSLocalizedDescriptionKey: "图片无法保存，请换一张图片"])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        wallpaper = resized
        wallpaperDarkening = Self.darkening(resized)
        return data
    }

    func removeWallpaper() {
        if let url = Self.wallpaperURL { try? FileManager.default.removeItem(at: url) }
        wallpaper = nil
    }

    func reset() {
        removeWallpaper()
        background = Color(argb: 0xFF74777B)
        accent = Color(argb: 0xFF0A9FFF)
        monet = false; density = 0.16; refraction = 0.5
        primary = Color(argb: 0xFF91CDFF); secondary = Color(argb: 0xFFB7C8DD); tertiary = Color(argb: 0xFFD6BDE5)
    }
}

extension Color {
    init(argb: UInt32) {
        self.init(.sRGB, red: Double((argb >> 16) & 255) / 255, green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255, opacity: Double((argb >> 24) & 255) / 255)
    }
    var argb: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return UInt32(a * 255) << 24 | UInt32(r * 255) << 16 | UInt32(g * 255) << 8 | UInt32(b * 255)
    }
    var readableForeground: Color {
        let value = argb
        let channels = [16, 8, 0].map { shift -> Double in
            let channel = Double((value >> shift) & 255) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        return luminance > 0.179 ? .black : .white
    }
}

struct WaterBackground: View {
    @ObservedObject var appearance: WaterAppearance
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                appearance.background
                if let image = appearance.wallpaper {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                Color.black.opacity(appearance.backgroundDarkening)
            }
        }.ignoresSafeArea()
    }
}

struct WaterGlass: ViewModifier {
    @ObservedObject var appearance: WaterAppearance
    var radius: CGFloat = 36
    var selected = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            if reduceTransparency {
                shape.fill(Color(argb: 0xFF3B414A))
            } else {
                glassBackground(shape: shape)
            }
        }
        .overlay(shape.strokeBorder(
            LinearGradient(colors: [.white.opacity(0.18 + appearance.refraction * 0.45), .black.opacity(0.35), .white.opacity(0.12 + appearance.refraction * 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75))
        .overlay(shape.strokeBorder(selected ? appearance.highlight.opacity(0.65) : .clear, lineWidth: 1.2))
        .clipShape(shape)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    @ViewBuilder private func glassBackground(shape: RoundedRectangle) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            shape.fill(.clear)
                .glassEffect(.regular.tint((appearance.monet ? appearance.primary : .white).opacity(appearance.density)), in: shape)
        } else {
            fallback(shape: shape)
        }
        #else
        fallback(shape: shape)
        #endif
    }

    private func fallback(shape: RoundedRectangle) -> some View {
        shape.fill(.ultraThinMaterial)
            .overlay(shape.fill((appearance.monet ? appearance.primary : .white).opacity(appearance.density)))
    }
}

extension View {
    func waterGlass(_ appearance: WaterAppearance, radius: CGFloat = 36, selected: Bool = false) -> some View {
        modifier(WaterGlass(appearance: appearance, radius: radius, selected: selected))
    }
}

/// PHPicker grants access only to the selected image, not the entire library.
struct WaterWallpaperPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: WaterWallpaperPicker
        init(_ parent: WaterWallpaperPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let onImage = parent.onImage
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { onImage(image) }
            }
        }
    }
}
