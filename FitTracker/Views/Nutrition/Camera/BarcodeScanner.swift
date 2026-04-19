// FitTracker/Views/Nutrition/Camera/BarcodeScanner.swift
// Barcode scanner sheet + UIViewController wrapping AVCaptureSession.
// Extracted from MealEntrySheet.swift in Audit M-2a (UI-004 decomposition).

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            BarcodeScannerView(onScan: { barcode in
                onScan(barcode)
            })
            .ignoresSafeArea()
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerVC, context: Context) {}

    final class Coordinator: NSObject, BarcodeScannerVCDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func barcodeScannerVC(_ vc: BarcodeScannerVC, didScanBarcode barcode: String) {
            guard !didScan else { return }
            didScan = true
            DispatchQueue.main.async { self.onScan(barcode) }
        }
    }
}

protocol BarcodeScannerVCDelegate: AnyObject {
    func barcodeScannerVC(_ vc: BarcodeScannerVC, didScanBarcode barcode: String)
}

final class BarcodeScannerVC: UIViewController {
    weak var delegate: BarcodeScannerVCDelegate?

    private let session        = AVCaptureSession()
    private var previewLayer:    AVCaptureVideoPreviewLayer?
    private let metadataQueue  = DispatchQueue(label: "com.fittracker.barcode")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        metadataQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        metadataQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func setupSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            showPermissionDenied()
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: metadataQueue)
            let supported: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .code128, .qr]
            output.metadataObjectTypes = supported.filter { output.availableMetadataObjectTypes.contains($0) }
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        // Scanning guide overlay
        let guide = UIView()
        guide.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        guide.layer.borderWidth = 2
        guide.layer.cornerRadius = 8
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            guide.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async {
            let label = UILabel()
            label.text = "Camera access is required to scan barcodes.\nPlease enable it in Settings."
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                label.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -40)
            ])
        }
    }
}

extension BarcodeScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        session.stopRunning()
        delegate?.barcodeScannerVC(self, didScanBarcode: value)
    }
}
#endif
