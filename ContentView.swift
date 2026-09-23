import SwiftUI

struct ContentView: View {
    @EnvironmentObject var m: PostureMonitor

    var color: Color {
        switch m.status {
        case .idle: .gray
        case .good: .green
        case .bad:  .red
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("DikDur").font(.largeTitle.bold())

            Label(m.connected ? "AirPods bağlı" : "AirPods bağlı değil",
                  systemImage: m.connected ? "airpodspro" : "airpodspro.slash")
                .foregroundStyle(m.connected ? .green : .secondary)

            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 180, height: 180)
                VStack {
                    Text(String(format: "%.0f°", m.deviation))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(m.status == .bad ? "Dik dur!" : m.status == .good ? "İyi" : "Hazır")
                        .foregroundStyle(color)
                }
            }

            VStack(alignment: .leading) {
                Text("Sınır: \(Int(m.threshold))°")
                Slider(value: $m.threshold, in: 5...40, step: 1)
                Text("Uyarı gecikmesi: \(Int(m.holdTime)) sn")
                Slider(value: $m.holdTime, in: 0...10, step: 1)
            }
            .padding(.horizontal)

            if m.isRunning {
                Button("Şu anki duruşu 'dik' olarak ayarla") { m.calibrate() }
                    .buttonStyle(.bordered)
            }

            Button(m.isRunning ? "Durdur" : "Başlat") {
                m.isRunning ? m.stop() : m.start()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let e = m.errorText {
                Text(e).foregroundStyle(.red).font(.footnote)
            }
            Spacer()
        }
        .padding()
    }
}
