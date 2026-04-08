import SwiftUI

struct WatchContentView: View {
    @StateObject private var heartRateManager = HeartRateManager()
    @StateObject private var imuManager = IMUManager()

    var body: some View {
        VStack(spacing: 8) {
            Text("Heart Rate")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(heartRateManager.heartRate, specifier: "%.0f") BPM")
                .font(.title2)
                .fontWeight(.bold)
                .padding(6)
                .background(heartRateColor(for: heartRateManager.heartRate))
                .cornerRadius(8)

            // Accelerometer section
            Text("Motion Monitor")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Display X/Y/Z with 2 decimal places
            Text(String(format: "x: %.2f  y: %.2f  z: %.2f",
                        imuManager.accel.indices.contains(0) ? imuManager.accel[0] : 0,
                        imuManager.accel.indices.contains(1) ? imuManager.accel[1] : 0,
                        imuManager.accel.indices.contains(2) ? imuManager.accel[2] : 0))
                .font(.footnote)
                .monospacedDigit()
        }
        .padding(10)
        .onAppear {
            imuManager.startAccelerometers()
        }
        .onDisappear {
            imuManager.stopAccelerometers()
        }
    }

    private func heartRateColor(for heartRate: Double) -> Color {
        switch heartRate {
        
        
        default: return .green
        }
    }
}

struct WatchContentView_Previews: PreviewProvider {
    static var previews: some View {
        WatchContentView()
    }
}
