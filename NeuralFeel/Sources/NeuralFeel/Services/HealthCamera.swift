import Foundation
import AVFoundation
import CoreImage

/// Camera-based heart rate detection using rPPG (remote photoplethysmography).
/// User places finger over the rear camera lens. The torch illuminates the fingertip
/// and blood-flow pulses are detected as brightness variations in the red channel.
@MainActor
final class HealthCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var heartRate: Double = 0
    @Published var isReading = false
    @Published var signalQuality: Double = 0    // 0–1

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.neuralfeel.camera", qos: .userInteractive)
    private var device: AVCaptureDevice?

    // Signal buffer — stores ~10 seconds of red-channel brightness samples at ~30fps
    private var samples: [Double] = []
    private let sampleWindow = 300   // 10s × 30fps
    private let minSamplesForBPM = 90

    // MARK: - Control

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return }
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam) else { return }
        device = cam
        session.beginConfiguration()
        session.sessionPreset = .low     // small frames = less CPU
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        // Lock torch at max for consistent illumination
        try? cam.lockForConfiguration()
        if cam.isTorchModeSupported(.on) { try? cam.setTorchModeOn(level: 1.0) }
        cam.unlockForConfiguration()

        session.startRunning()
        isReading = true
    }

    func stop() {
        session.stopRunning()
        try? device?.lockForConfiguration()
        device?.torchMode = .off
        device?.unlockForConfiguration()
        isReading = false
        samples.removeAll()
    }

    // MARK: - Frame processing (runs on camera queue)

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let brightness = redChannelBrightness(pixelBuffer)
        Task { @MainActor in
            self.ingest(brightness)
        }
    }

    // MARK: - Signal processing

    private func ingest(_ value: Double) {
        samples.append(value)
        if samples.count > sampleWindow { samples.removeFirst() }
        guard samples.count >= minSamplesForBPM else { return }

        let bpm = estimateBPM(samples: samples, fps: 30)
        heartRate = bpm
        signalQuality = bpm > 0 ? 1.0 : 0.3
    }

    /// Peak-counting BPM from a brightness signal via zero-crossing on high-pass filtered data.
    private func estimateBPM(samples: [Double], fps: Double) -> Double {
        // 1. Normalize
        let mean = samples.reduce(0, +) / Double(samples.count)
        let detrended = samples.map { $0 - mean }

        // 2. Simple moving-average high-pass (remove slow drift)
        let winSize = 15
        var highPassed = [Double](repeating: 0, count: detrended.count)
        for i in winSize..<detrended.count {
            let window = detrended[(i - winSize)..<i]
            highPassed[i] = detrended[i] - window.reduce(0, +) / Double(winSize)
        }

        // 3. Count positive zero crossings (each = one beat)
        var crossings = 0
        for i in 1..<highPassed.count {
            if highPassed[i - 1] < 0 && highPassed[i] >= 0 { crossings += 1 }
        }
        let durationSeconds = Double(samples.count) / fps
        let bpm = Double(crossings) / durationSeconds * 60.0

        // Sanity clamp: human HR 40–200 bpm
        return (40...200).contains(bpm) ? bpm.rounded() : 0
    }

    // MARK: - Pixel analysis

    private nonisolated func redChannelBrightness(_ buffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let width  = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)

        // Sample center 20×20 patch for stability
        let cx = width / 2, cy = height / 2, r = 10
        var redSum = 0.0, count = 0
        for y in (cy - r)..<(cy + r) {
            for x in (cx - r)..<(cx + r) {
                let pixel = base.advanced(by: y * stride + x * 4)
                    .assumingMemoryBound(to: UInt8.self)
                redSum += Double(pixel[2])  // BGRA → index 2 = red
                count += 1
            }
        }
        return count > 0 ? redSum / Double(count) : 0
    }
}
