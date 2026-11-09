import SwiftUI
#if os(iOS)
import AVFoundation
#endif

struct QRImportView: View {
    let onSave: (VPNServer) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scanned = ""
    @State private var preview: VPNServer?
    @State private var errorText: String?
    @State private var manual = ""

    var body: some View {
        ZStack {
            MistBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("QR или ссылка")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(OloTheme.ink)

                    #if os(iOS)
                    CameraQRScanner { code in
                        apply(code)
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    #else
                    Text("На Mac: вставьте ссылку из QR (или Continiuity Camera позже).")
                        .font(OloTheme.captionFont)
                        .foregroundStyle(OloTheme.inkSoft)
                    #endif

                    TextField("ss://… / vless://…", text: $manual)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .padding(14)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onSubmit { apply(manual) }

                    BigButton(title: "Разобрать", systemImage: "qrcode.viewfinder", style: .secondary) {
                        apply(manual)
                    }

                    if let errorText {
                        Text(errorText).font(OloTheme.captionFont).foregroundStyle(OloTheme.coral)
                    }

                    if let preview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(preview.displayName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("\(preview.proto.title) · \(preview.endpointLabel)")
                                .font(OloTheme.captionFont)
                                .foregroundStyle(OloTheme.inkSoft)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        BigButton(title: "Сохранить", systemImage: "checkmark.circle.fill", style: .primary) {
                            onSave(preview)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("QR")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func apply(_ raw: String) {
        do {
            preview = try LinkParser.parse(raw)
            scanned = raw
            errorText = nil
        } catch {
            preview = nil
            errorText = error.localizedDescription
        }
    }
}

#if os(iOS)
struct CameraQRScanner: UIViewRepresentable {
    var onCode: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = CameraQRUIView()
        view.onCode = onCode
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class CameraQRUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var didSetup = false

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
        if !didSetup {
            didSetup = true
            setup()
        }
    }

    private func setup() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.insertSublayer(preview, at: 0)
        DispatchQueue.global().async { self.session.startRunning() }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        onCode?(value)
    }
}
#endif
