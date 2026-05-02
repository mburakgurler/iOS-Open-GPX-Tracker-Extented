//
//  SensorSnapshot.swift
//  OpenGpxTracker
//
//  Latest sensor sample captured at GPX track point recording time.
//

import Foundation

/// One consolidated sample aligned with a single GPS track point.
struct SensorSnapshot {
    var timestamp: Date

    var accelerometerX: Double?
    var accelerometerY: Double?
    var accelerometerZ: Double?

    var gyroscopeX: Double?
    var gyroscopeY: Double?
    var gyroscopeZ: Double?

    var magnetometerX: Double?
    var magnetometerY: Double?
    var magnetometerZ: Double?

    var pressureKPa: Double?
    var relativeAltitudeMeters: Double?

    var roll: Double?
    var pitch: Double?
    var yaw: Double?

    static func empty(at date: Date = Date()) -> SensorSnapshot {
        SensorSnapshot(
            timestamp: date,
            accelerometerX: nil, accelerometerY: nil, accelerometerZ: nil,
            gyroscopeX: nil, gyroscopeY: nil, gyroscopeZ: nil,
            magnetometerX: nil, magnetometerY: nil, magnetometerZ: nil,
            pressureKPa: nil, relativeAltitudeMeters: nil,
            roll: nil, pitch: nil, yaw: nil
        )
    }
}
