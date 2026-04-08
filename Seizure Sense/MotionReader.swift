//
//  MotionReader.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.


import UIKit
import CoreMotion
import Accelerate
import AudioToolbox

extension Notification.Name {
    static let seizureDetected = Notification.Name("SeizureDetectedNotification")
}

class ViewController: UIViewController {
    
    let motionManager = CMMotionManager()
    
    let sampleRate = 50.0
    let bufferSize = 256
    
    var accelBuffer: [Double] = []
    
    // Detection parameters
    let minSeizureFreq = 3.0
    let maxSeizureFreq = 8.0
    let amplitudeThreshold = 0.8      // Adjust experimentally
    let requiredConsecutiveDetections = 3
    
    var consecutiveDetections = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startAccelerometer()
    }
    
    func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 1.0 / sampleRate
        
        motionManager.startAccelerometerUpdates(to: OperationQueue()) { data, error in
            guard let data = data else { return }
            
            // Magnitude minus gravity (~1g)
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            ) - 1.0
            
            self.accelBuffer.append(magnitude)
            
            if self.accelBuffer.count >= self.bufferSize {
                self.analyzeBuffer()
                self.accelBuffer.removeAll()
            }
        }
    }
    
    func analyzeBuffer() {
        let rms = calculateRMS(accelBuffer)
        
        let dominantFreq = performFFT(accelBuffer)
        
        print("Freq: \(dominantFreq) Hz | RMS: \(rms)")
        
        if dominantFreq >= minSeizureFreq &&
           dominantFreq <= maxSeizureFreq &&
           rms > amplitudeThreshold {
            
            consecutiveDetections += 1
            
            if consecutiveDetections >= requiredConsecutiveDetections {
                triggerAlert()
                consecutiveDetections = 0
            }
            
        } else {
            consecutiveDetections = 0
        }
    }
    
    func calculateRMS(_ data: [Double]) -> Double {
        let sumSquares = data.map { $0 * $0 }.reduce(0, +)
        return sqrt(sumSquares / Double(data.count))
    }
    
    func performFFT(_ data: [Double]) -> Double {
        var windowed = data
        applyHammingWindow(&windowed)

        // Prepare real and imaginary buffers with capacity = bufferSize
        var real = windowed
        if real.count < bufferSize { real.append(contentsOf: repeatElement(0.0, count: bufferSize - real.count)) }
        else if real.count > bufferSize { real.removeLast(real.count - bufferSize) }
        var imaginary = [Double](repeating: 0.0, count: bufferSize)

        let log2n = vDSP_Length(log2(Double(bufferSize)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else { return 0.0 }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Use stable pointers for split-complex representation
        let dominantFreq: Double = real.withUnsafeMutableBufferPointer { realBuf in
            imaginary.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPDoubleSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)

                vDSP_fft_zipD(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                // Magnitudes for first N/2 bins
                var magnitudes = [Double](repeating: 0.0, count: bufferSize / 2)
                vDSP_zvmagsD(&split, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))

                // Find max magnitude index
                let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
                return Double(maxIndex) * sampleRate / Double(bufferSize)
            }
        }

        return dominantFreq
    }
    
    func applyHammingWindow(_ data: inout [Double]) {
        for i in 0..<data.count {
            let multiplier = 0.54 - 0.46 * cos(2.0 * .pi * Double(i) / Double(data.count - 1))
            data[i] *= multiplier
        }
    }
    
    func triggerAlert() {
        print("⚠️ Seizure-like motion detected!")

        // Post a notification so SwiftUI ContentView can present UI
        NotificationCenter.default.post(name: .seizureDetected, object: nil)

        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(SystemSoundID(1005))
            let originalColor = self.view.backgroundColor
            self.view.backgroundColor = .red
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.view.backgroundColor = originalColor
            }
        }
    }
}


