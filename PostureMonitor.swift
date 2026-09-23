import Foundation
import CoreMotion

@MainActor
final class PostureMonitor: NSObject, ObservableObject, CMHeadphoneMotionManagerDelegate {
    enum Status { case idle, good, bad }

    @Published var isRunning = false
    @Published var connected = false
    @Published var deviation: Double = 0          // derece
    @Published var status: Status = .idle
    @Published var errorText: String?

    @Published var threshold: Double = UserDefaults.standard.object(forKey: "threshold") as? Double ?? 15 {
        didSet { UserDefaults.standard.set(threshold, forKey: "threshold") }
    }
    @Published var holdTime: Double = UserDefaults.standard.object(forKey: "holdTime") as? Double ?? 3 {
        didSet { UserDefaults.standard.set(holdTime, forKey: "holdTime") }
    }

    private let motion = CMHeadphoneMotionManager()
    let tones = ToneEngine()
    private var reference: Double?
    private var currentPitch: Double = 0
    private var badSince: Date?
    private var goodSince: Date?
    private let hysteresis = 3.0   // sınırda titreşip sürekli bip çalmasın diye

    override init() {
        super.init()
        motion.delegate = self
    }

    func start() {
        errorText = nil
        guard motion.isDeviceMotionAvailable else {
            errorText = "Bu cihazda kulaklık hareket verisi kullanılamıyor."
            return
        }
        do { try tones.start() } catch {
            errorText = "Ses başlatılamadı: \(error.localizedDescription)"
            return
        }
        reference = nil   // ilk gelen değer dik duruş kabul edilir
        status = .idle
        badSince = nil; goodSince = nil

        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, err in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let err { self.errorText = err.localizedDescription; return }
                if let m { self.process(m) }
            }
        }
        isRunning = true
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        tones.stop()
        isRunning = false
        status = .idle
    }

    /// Şu anki baş pozisyonunu "dik duruş" olarak kaydeder
    func calibrate() {
        reference = currentPitch
        status = .good
        badSince = nil; goodSince = nil
    }

    private func process(_ m: CMDeviceMotion) {
        let pitch = m.attitude.pitch * 180 / .pi
        currentPitch = pitch
        if reference == nil { reference = pitch; status = .good }
        guard let ref = reference else { return }

        let dev = abs(pitch - ref)
        deviation = dev
        let now = Date()

        switch status {
        case .idle, .good:
            if dev > threshold {
                if badSince == nil { badSince = now }
                if now.timeIntervalSince(badSince!) >= holdTime {
                    status = .bad
                    badSince = nil
                    tones.playBad()
                }
            } else {
                badSince = nil
            }
        case .bad:
            if dev < threshold - hysteresis {
                if goodSince == nil { goodSince = now }
                if now.timeIntervalSince(goodSince!) >= 0.5 {
                    status = .good
                    goodSince = nil
                    tones.playGood()
                }
            } else {
                goodSince = nil
            }
        }
    }

    // MARK: - Kulaklık bağlantı durumu
    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in self.connected = true }
    }
    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in self.connected = false }
    }
}
