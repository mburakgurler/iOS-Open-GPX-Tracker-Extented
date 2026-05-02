//
//  GPXSensorExtensionBuilder.swift
//  OpenGpxTracker
//
//  Maps SensorSnapshot into CoreGPX extensions under the sensor namespace.
//

import Foundation
import CoreGPX

enum GPXSensorExtensionBuilder {

    private static let snapshotTag = "sensor:snapshot"
    private static let accelerometerTag = "sensor:accelerometer"
    private static let gyroscopeTag = "sensor:gyroscope"
    private static let magnetometerTag = "sensor:magnetometer"
    private static let barometerTag = "sensor:barometer"
    private static let attitudeTag = "sensor:attitude"

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func format(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.6f", value)
    }

    /// Builds `<extensions><sensor:snapshot>…</sensor:snapshot></extensions>` or returns nil if nothing to emit.
    static func gpxExtensions(from snapshot: SensorSnapshot, detailLevel: SensorDetailLevel) -> GPXExtensions? {
        let root = GPXExtensions()
        let snap = GPXExtensionsElement(name: snapshotTag)
        snap.attributes["timestamp"] = iso8601Formatter.string(from: snapshot.timestamp)

        func addTriplet(tag: String, x: Double?, y: Double?, z: Double?) {
            guard x != nil || y != nil || z != nil else { return }
            let el = GPXExtensionsElement(name: tag)
            if let s = format(x) { el.attributes["x"] = s }
            if let s = format(y) { el.attributes["y"] = s }
            if let s = format(z) { el.attributes["z"] = s }
            snap.children.append(el)
        }

        addTriplet(tag: accelerometerTag, x: snapshot.accelerometerX, y: snapshot.accelerometerY, z: snapshot.accelerometerZ)

        if detailLevel == .advanced {
            addTriplet(tag: gyroscopeTag, x: snapshot.gyroscopeX, y: snapshot.gyroscopeY, z: snapshot.gyroscopeZ)
            addTriplet(tag: magnetometerTag, x: snapshot.magnetometerX, y: snapshot.magnetometerY, z: snapshot.magnetometerZ)
        }

        if snapshot.pressureKPa != nil || snapshot.relativeAltitudeMeters != nil {
            let baro = GPXExtensionsElement(name: barometerTag)
            if let p = format(snapshot.pressureKPa) { baro.attributes["pressure"] = p }
            if let r = format(snapshot.relativeAltitudeMeters) { baro.attributes["relativeAltitude"] = r }
            snap.children.append(baro)
        }

        if snapshot.roll != nil || snapshot.pitch != nil || snapshot.yaw != nil {
            let att = GPXExtensionsElement(name: attitudeTag)
            if let s = format(snapshot.roll) { att.attributes["roll"] = s }
            if let s = format(snapshot.pitch) { att.attributes["pitch"] = s }
            if let s = format(snapshot.yaw) { att.attributes["yaw"] = s }
            snap.children.append(att)
        }

        guard !snap.children.isEmpty else { return nil }

        root.children.append(snap)
        return root
    }
}
