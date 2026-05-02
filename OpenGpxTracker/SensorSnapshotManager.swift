//
//  SensorSnapshotManager.swift
//  OpenGpxTracker
//
//  Runs Core Motion / altimeter at modest rates and exposes the latest sample for GPX points.
//

import Foundation
import CoreMotion

final class SensorSnapshotManager {

    static let shared = SensorSnapshotManager()

    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "OpenGpxTracker.SensorSnapshot"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private let lock = NSLock()
    private var stash = SensorSnapshot.empty()
    private var lastBarometerApply: TimeInterval?

    private init() {}

    func start() {
        guard Preferences.shared.includeSensorDataInGPX else { return }

        stop()

        let advanced = Preferences.shared.sensorDetailLevel == .advanced
        let accelInterval = advanced ? 0.1 : 0.2
        let motionInterval = advanced ? 0.1 : 0.2

        lock.lock()
        stash = SensorSnapshot.empty()
        lastBarometerApply = nil
        lock.unlock()

        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = accelInterval
            motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                let a = data.acceleration
                self.mutate {
                    $0.timestamp = Date()
                    $0.accelerometerX = a.x
                    $0.accelerometerY = a.y
                    $0.accelerometerZ = a.z
                }
            }
        }

        if advanced {
            if motion.isGyroAvailable {
                motion.gyroUpdateInterval = 0.1
                motion.startGyroUpdates(to: queue) { [weak self] data, _ in
                    guard let self, let data else { return }
                    let r = data.rotationRate
                    self.mutate {
                        $0.timestamp = Date()
                        $0.gyroscopeX = r.x
                        $0.gyroscopeY = r.y
                        $0.gyroscopeZ = r.z
                    }
                }
            }
            if motion.isMagnetometerAvailable {
                motion.magnetometerUpdateInterval = 0.2
                motion.startMagnetometerUpdates(to: queue) { [weak self] data, _ in
                    guard let self, let data else { return }
                    let f = data.magneticField
                    self.mutate {
                        $0.timestamp = Date()
                        $0.magnetometerX = f.x
                        $0.magnetometerY = f.y
                        $0.magnetometerZ = f.z
                    }
                }
            }
        }

        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = motionInterval
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] data, _ in
                guard let self, let att = data?.attitude else { return }
                self.mutate {
                    $0.timestamp = Date()
                    $0.roll = att.roll
                    $0.pitch = att.pitch
                    $0.yaw = att.yaw
                }
            }
        }

        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                let now = ProcessInfo.processInfo.systemUptime
                self.lock.lock()
                let last = self.lastBarometerApply
                if let last, now - last < 1.0 {
                    self.lock.unlock()
                    return
                }
                self.lastBarometerApply = now
                self.lock.unlock()

                self.mutate {
                    $0.timestamp = Date()
                    $0.pressureKPa = data.pressure.doubleValue
                    $0.relativeAltitudeMeters = data.relativeAltitude.doubleValue
                }
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        motion.stopGyroUpdates()
        motion.stopMagnetometerUpdates()
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    func currentSnapshot() -> SensorSnapshot {
        lock.lock()
        let copy = stash
        lock.unlock()
        return copy
    }

    private func mutate(_ body: (inout SensorSnapshot) -> Void) {
        lock.lock()
        body(&stash)
        lock.unlock()
    }
}
