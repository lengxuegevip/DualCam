import UIKit
import AVFoundation
import Photos

/// 前后双摄同屏：基于 AVCaptureMultiCamSession（iOS 13+）
/// 需要 A12 仿生芯片及以上机型（iPhone XS / XR 及更新）
final class ViewController: UIViewController {

    // MARK: - 会话与设备
    private let session = AVCaptureMultiCamSession()

    private lazy var frontPreviewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    private lazy var backPreviewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)

    private var frontInput: AVCaptureDeviceInput?
    private var backInput: AVCaptureDeviceInput?
    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var backPhotoOutput: AVCapturePhotoOutput?

    private var frontInMain = false          // 默认后置为主画面
    private var isConfigured = false
    private var savers: [PhotoSaver] = []
    private var statusTimer: Timer?

    // MARK: - UI
    private let mainContainer = UIView()
    private let pipContainer = UIView()
    private let frontBadge = UILabel()
    private let backBadge = UILabel()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private let flashView = UIView()

    private let shutterButton = UIButton(type: .custom)
    private let swapButton = UIButton(type: .system)
    private let torchButton = UIButton(type: .system)

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        requestPermissions()
        addObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width
        let h = view.bounds.height
        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom

        mainContainer.frame = view.bounds

        let pipW: CGFloat = min(120, w * 0.34)
        let pipH = pipW * 4.0 / 3.0
        pipContainer.frame = CGRect(x: w - pipW - 16,
                                    y: safeTop + 58,
                                    width: pipW,
                                    height: pipH)
        pipContainer.layer.cornerRadius = 12

        titleLabel.frame = CGRect(x: 18, y: safeTop + 14, width: w - 36, height: 32)

        let side: CGFloat = 60
        let shutter: CGFloat = 76
        let centerY = h - safeBottom - 108
        shutterButton.frame = CGRect(x: (w - shutter) / 2, y: centerY, width: shutter, height: shutter)
        shutterButton.layer.cornerRadius = shutter / 2
        swapButton.frame = CGRect(x: (w - shutter) / 2 - side - 26, y: centerY + 8, width: side, height: side)
        torchButton.frame = CGRect(x: (w - shutter) / 2 + shutter + 26, y: centerY + 8, width: side, height: side)

        statusLabel.frame = CGRect(x: 24, y: h - safeBottom - 196, width: w - 48, height: 34)
        flashView.frame = view.bounds
        errorView.frame = view.bounds
        errorLabel.frame = CGRect(x: 28, y: 0, width: w - 56, height: h)

        if isConfigured { applyLayout() }
    }

    // MARK: - UI 构建
    private func buildUI() {
        mainContainer.backgroundColor = .black
        mainContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(swapTapped)))
        view.addSubview(mainContainer)

        pipContainer.backgroundColor = .black
        pipContainer.clipsToBounds = true
        pipContainer.layer.borderWidth = 1.5
        pipContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        pipContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(swapTapped)))
        view.addSubview(pipContainer)

        for badge in [frontBadge, backBadge] {
            badge.font = .systemFont(ofSize: 11, weight: .semibold)
            badge.textColor = .white
            badge.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            badge.textAlignment = .center
            badge.layer.cornerRadius = 4
            badge.clipsToBounds = true
            badge.sizeToFit()
        }
        frontBadge.text = "前置"
        backBadge.text = "后置"

        titleLabel.text = "前后双摄 · 同屏"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        shutterButton.backgroundColor = .white
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        view.addSubview(shutterButton)

        let inner = UIView(frame: CGRect(x: 7, y: 7, width: 62, height: 62))
        inner.backgroundColor = UIColor.white
        inner.layer.cornerRadius = 31
        inner.isUserInteractionEnabled = false
        shutterButton.addSubview(inner)

        swapButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        swapButton.tintColor = .white
        swapButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        swapButton.layer.cornerRadius = 30
        swapButton.addTarget(self, action: #selector(swapTapped), for: .touchUpInside)
        view.addSubview(swapButton)

        torchButton.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        torchButton.tintColor = .white
        torchButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        torchButton.layer.cornerRadius = 30
        torchButton.addTarget(self, action: #selector(torchTapped), for: .touchUpInside)
        view.addSubview(torchButton)

        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.isHidden = true
        view.addSubview(statusLabel)

        flashView.backgroundColor = .white
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        view.addSubview(flashView)

        errorView.backgroundColor = UIColor(white: 0.08, alpha: 0.96)
        errorLabel.textColor = .white
        errorLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorView.addSubview(errorLabel)
        errorView.isHidden = true
        view.addSubview(errorView)
    }

    // MARK: - 权限
    private func requestPermissions() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() }
                    else { self?.showError("未获得相机权限。\n请到「设置 → 隐私与安全性 → 相机」中开启本 App。") }
                }
            }
        default:
            showError("相机权限被拒绝。\n请到「设置 → 隐私与安全性 → 相机」中开启本 App。")
        }
    }

    // MARK: - 会话配置
    private enum SetupError: LocalizedError {
        case noCameras
        case addInput
        case addOutput
        case addConnection

        var errorDescription: String? {
            switch self {
            case .noCameras: return "未找到前置或后置摄像头。"
            case .addInput: return "无法添加摄像头输入（系统限制或硬件被占用）。"
            case .addOutput: return "无法添加拍照输出。"
            case .addConnection: return "无法建立双摄连接，请关闭其他占用相机的 App 后重试。"
            }
        }
    }

    private func setupSession() {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            showError("此设备不支持前后摄像头同时工作。\n需要 iPhone XS / XR 及更新机型，且 iOS 13 以上。")
            return
        }
        do {
            try configureSession()
        } catch {
            showError(error.localizedDescription)
            return
        }
        isConfigured = true
        applyLayout()
        startSession()
    }

    private func configureSession() throws {
        guard let backDev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let frontDev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw SetupError.noCameras
        }

        // 限制分辨率，降低双摄硬件开销，避免被系统降帧或断开
        // 选不超过 1280 宽的格式：两路 720p 足以流畅同屏，且硬件预算安全
        selectModerateFormat(for: backDev)
        selectModerateFormat(for: frontDev)

        let backIn = try AVCaptureDeviceInput(device: backDev)
        let frontIn = try AVCaptureDeviceInput(device: frontDev)

        let backOut = AVCapturePhotoOutput()
        let frontOut = AVCapturePhotoOutput()
        backOut.isHighResolutionCaptureEnabled = false
        frontOut.isHighResolutionCaptureEnabled = false

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(backIn), session.canAddInput(frontIn) else { throw SetupError.addInput }
        session.addInputWithNoConnections(backIn)
        session.addInputWithNoConnections(frontIn)

        guard session.canAddOutput(backOut), session.canAddOutput(frontOut) else { throw SetupError.addOutput }
        session.addOutputWithNoConnections(backOut)
        session.addOutputWithNoConnections(frontOut)

        guard let backPort = backIn.ports.first, let frontPort = frontIn.ports.first else {
            throw SetupError.addConnection
        }
        let backVideoConn = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: backPreviewLayer)
        let frontVideoConn = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: frontPreviewLayer)

        guard session.canAddConnection(backVideoConn), session.canAddConnection(frontVideoConn) else {
            throw SetupError.addConnection
        }

        // 画面填充方式由预览层的 videoGravity 决定（见 applyLayout）
        if frontVideoConn.isVideoMirroringSupported { frontVideoConn.isVideoMirrored = true }

        session.addConnection(backVideoConn)
        session.addConnection(frontVideoConn)

        let backPhotoConn = AVCaptureConnection(inputPorts: backIn.ports, output: backOut)
        let frontPhotoConn = AVCaptureConnection(inputPorts: frontIn.ports, output: frontOut)
        guard session.canAddConnection(backPhotoConn), session.canAddConnection(frontPhotoConn) else {
            throw SetupError.addConnection
        }
        session.addConnection(backPhotoConn)
        session.addConnection(frontPhotoConn)

        backInput = backIn
        frontInput = frontIn
        backPhotoOutput = backOut
        frontPhotoOutput = frontOut
    }

    private func selectModerateFormat(for device: AVCaptureDevice) {
        let candidates = device.formats.filter { $0.videoDimensions.width <= 1280 }
        guard let format = candidates.max(by: { $0.videoDimensions.width < $1.videoDimensions.width }) else { return }
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            device.unlockForConfiguration()
        } catch { /* 使用系统默认格式 */ }
    }

    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func stopSession() {
        if session.isRunning { session.stopRunning() }
    }

    // MARK: - 布局（切换主/副画面）
    private func applyLayout() {
        let mainLayer = frontInMain ? frontPreviewLayer : backPreviewLayer
        let pipLayer = frontInMain ? backPreviewLayer : frontPreviewLayer
        let mainBadge = frontInMain ? frontBadge : backBadge
        let pipBadge = frontInMain ? backBadge : frontBadge

        frontPreviewLayer.removeFromSuperlayer()
        backPreviewLayer.removeFromSuperlayer()
        frontBadge.removeFromSuperview()
        backBadge.removeFromSuperview()

        mainLayer.frame = mainContainer.bounds
        mainLayer.videoGravity = .resizeAspectFill
        mainContainer.layer.insertSublayer(mainLayer, at: 0)
        mainContainer.addSubview(mainBadge)
        mainBadge.frame = CGRect(x: 14, y: 8, width: 52, height: 22)

        pipLayer.frame = pipContainer.bounds
        pipLayer.videoGravity = .resizeAspectFill
        pipContainer.layer.insertSublayer(pipLayer, at: 0)
        pipContainer.addSubview(pipBadge)
        pipBadge.frame = CGRect(x: 6, y: 6, width: 46, height: 20)
    }

    // MARK: - 交互
    @objc private func swapTapped() {
        guard isConfigured else { return }
        frontInMain.toggle()
        applyLayout()
        showStatus(frontInMain ? "前置已切换为主画面" : "后置已切换为主画面")
    }

    @objc private func shutterTapped() {
        guard isConfigured, let backOut = backPhotoOutput, let frontOut = frontPhotoOutput else { return }

        capture(output: backOut) { [weak self] saver in
            self?.savers.removeAll { $0 === saver }
        }
        capture(output: frontOut) { [weak self] saver in
            self?.savers.removeAll { $0 === saver }
        }

        UIView.animate(withDuration: 0.08, animations: { self.flashView.alpha = 0.85 }) { _ in
            UIView.animate(withDuration: 0.22) { self.flashView.alpha = 0 }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func capture(output: AVCapturePhotoOutput, completion: @escaping (PhotoSaver) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        let saver = PhotoSaver()
        saver.onFinish = { saver in
            DispatchQueue.main.async { completion(saver) }
        }
        savers.append(saver)
        output.capturePhoto(with: settings, delegate: saver)
    }

    @objc private func torchTapped() {
        guard let device = backInput?.device, device.hasTorch else {
            showStatus("此设备后置摄像头没有手电筒")
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = (device.torchMode == .on) ? .off : .on
            device.unlockForConfiguration()
            let on = device.torchMode == .on
            torchButton.setImage(UIImage(systemName: on ? "flashlight.on.fill" : "flashlight.off.fill"), for: .normal)
            torchButton.tintColor = on ? .systemYellow : .white
            showStatus(on ? "手电筒已开启" : "手电筒已关闭")
        } catch {
            showStatus("手电筒切换失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 状态提示
    private func showStatus(_ text: String) {
        statusLabel.text = text
        statusLabel.isHidden = false
        statusLabel.superview?.bringSubviewToFront(statusLabel)
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.statusLabel.isHidden = true
        }
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorView.isHidden = false
        view.bringSubviewToFront(errorView)
    }

    // MARK: - 前后台
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func becameActive() { if isConfigured { startSession() } }
    @objc private func enteredBackground() { stopSession() }
}

// MARK: - 照片保存代理
final class PhotoSaver: NSObject, AVCapturePhotoCaptureDelegate {
    var onFinish: ((PhotoSaver) -> Void)?

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { onFinish?(self) }
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
}
