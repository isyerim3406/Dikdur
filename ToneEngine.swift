import AVFoundation

@MainActor
final class ToneEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let silence = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var active = false

    init() {
        engine.attach(player)
        engine.attach(silence)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(silence, to: engine.mainMixerNode, format: format)

        // Kulaklık bağlanıp kopunca motor durur -> yeniden başlat
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        }
        // Telefon araması vb. kesinti bitince yeniden başlat
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw == AVAudioSession.InterruptionType.ended.rawValue {
                MainActor.assumeIsolated { self?.restartIfNeeded() }
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.mixWithOthers]) // müzik/podcast ile birlikte çalışır
        try session.setActive(true)
        active = true
        try startNodes()
    }

    func stop() {
        active = false
        player.stop()
        silence.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startNodes() throws {
        if !engine.isRunning { try engine.start() }
        // Sessiz döngü: iOS'un uygulamayı arka planda askıya almasını engeller
        let frames = AVAudioFrameCount(format.sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let d = buf.floatChannelData![0]
        for i in 0..<Int(frames) { d[i] = 0 }
        silence.stop()
        silence.scheduleBuffer(buf, at: nil, options: .loops)
        silence.play()
        player.play()
    }

    private func restartIfNeeded() {
        guard active else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? startNodes()
    }

    // Kötü duruş: iki alçalan bip
    func playBad()  { play([(880, 0.15), (440, 0.25)]) }
    // Düzeldi: tek yükselen bip
    func playGood() { play([(660, 0.10), (1320, 0.18)]) }

    private func play(_ notes: [(freq: Double, dur: Double)]) {
        guard active else { return }
        let sr = format.sampleRate
        let gap = 0.05
        let total = notes.reduce(0) { $0 + $1.dur + gap }
        let count = Int(total * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buf.frameLength = AVAudioFrameCount(count)
        let data = buf.floatChannelData![0]
        for i in 0..<count { data[i] = 0 }

        var idx = 0
        for note in notes {
            let n = Int(note.dur * sr)
            for i in 0..<n where idx + i < count {
                let t = Double(i) / sr
                let env = min(1.0, Double(i) / 400, Double(n - i) / 400) // tık sesini önlemek için yumuşak giriş/çıkış
                data[idx + i] = Float(sin(2 * .pi * note.freq * t) * 0.5 * env)
            }
            idx += n + Int(gap * sr)
        }
        player.scheduleBuffer(buf, at: nil, options: .interrupts)
    }
}
