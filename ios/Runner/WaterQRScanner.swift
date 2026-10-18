import AVFoundation
import SwiftUI
import UIKit

struct WaterQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> WaterQRScannerController {
        WaterQRScannerController(onCode: onCode)
    }
    func updateUIViewController(_ uiViewController: WaterQRScannerController, context: Context) {}
    static func dismantleUIViewController(_ uiViewController: WaterQRScannerController, coordinator: ()) {
        uiViewController.stop()
    }
}

final class WaterQRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.fakeuy.water.qr-camera")
    private var preview: AVCaptureVideoPreviewLayer?
    private var completed = false
    private var configured = false
    private var visible = false
    private let onCode: (String) -> Void
    private let status = UILabel()
    private let retry = UIButton(type: .system)

    init(onCode: @escaping (String) -> Void) { self.onCode = onCode; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        status.text = "将设备二维码放入取景画面"
        status.textColor = .white; status.numberOfLines = 0; status.textAlignment = .center
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.translatesAutoresizingMaskIntoConstraints = false
        retry.setTitle("重新扫描", for: .normal)
        retry.addTarget(self, action: #selector(restart), for: .touchUpInside)
        retry.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status); view.addSubview(retry)
        NSLayoutConstraint.activate([
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            status.bottomAnchor.constraint(equalTo: retry.topAnchor, constant: -15),
            retry.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retry.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); visible = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, self.visible else { return }
                    if granted { self.configure() } else { self.status.text = "请在系统设置中允许相机访问，以扫描设备二维码。" }
                }
            }
        default: status.text = "相机权限尚未开启。请前往系统设置允许访问，或返回按位置添加设备。"
        }
    }

    private func configure() {
        guard !configured else { restart(); return }
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera) else {
            status.text = "无法使用相机，请返回按位置添加设备。"; return
        }
        let output = AVCaptureMetadataOutput()
        guard session.canAddInput(input), session.canAddOutput(output) else { status.text = "相机初始化失败，请重新打开扫码。"; return }
        session.beginConfiguration(); session.addInput(input); session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration(); configured = true
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0); preview = layer; layer.frame = view.bounds
        restart()
    }

    @objc private func restart() {
        guard configured, visible else { return }
        completed = false; status.text = "将设备二维码放入取景画面"
        queue.async { [weak self] in guard let self = self, !self.session.isRunning else { return }; self.session.startRunning() }
    }

    func stop() { queue.async { [weak self] in if self?.session.isRunning == true { self?.session.stopRunning() } } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); visible = false; stop() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !completed, let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, !code.isEmpty else { return }
        completed = true; stop(); status.text = "已识别，正在绑定设备…"; onCode(code)
    }
}
