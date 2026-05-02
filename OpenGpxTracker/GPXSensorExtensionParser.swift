//
//  GPXSensorExtensionParser.swift
//  OpenGpxTracker
//
//  Reads sensor blocks written by GPXSensorExtensionBuilder from CoreGPX extensions.
//

import Foundation
import CoreGPX

enum GPXSensorExtensionParser {

    private static let snapshotTag = "sensor:snapshot"
    private static let accelerometerTag = "sensor:accelerometer"
    private static let gyroscopeTag = "sensor:gyroscope"
    private static let magnetometerTag = "sensor:magnetometer"
    private static let barometerTag = "sensor:barometer"
    private static let attitudeTag = "sensor:attitude"

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Parses the first `sensor:snapshot` under `trkpt` extensions, if any.
    static func sensorSnapshot(from point: GPXTrackPoint) -> SensorSnapshot? {
        guard let ext = point.extensions else { return nil }
        for child in ext.children where child.name == snapshotTag {
            return parseSnapshotElement(child)
        }
        return nil
    }

    private static func parseSnapshotElement(_ snap: GPXExtensionsElement) -> SensorSnapshot? {
        var out = SensorSnapshot.empty()
        if let ts = snap.attributes["timestamp"] {
            let d = iso8601Fractional.date(from: ts) ?? iso8601Plain.date(from: ts)
            if let d = d {
                out.timestamp = d
            }
        }

        for el in snap.children {
            switch el.name {
            case accelerometerTag:
                out.accelerometerX = doubleAttr(el, "x")
                out.accelerometerY = doubleAttr(el, "y")
                out.accelerometerZ = doubleAttr(el, "z")
            case gyroscopeTag:
                out.gyroscopeX = doubleAttr(el, "x")
                out.gyroscopeY = doubleAttr(el, "y")
                out.gyroscopeZ = doubleAttr(el, "z")
            case magnetometerTag:
                out.magnetometerX = doubleAttr(el, "x")
                out.magnetometerY = doubleAttr(el, "y")
                out.magnetometerZ = doubleAttr(el, "z")
            case barometerTag:
                out.pressureKPa = doubleAttr(el, "pressure")
                out.relativeAltitudeMeters = doubleAttr(el, "relativeAltitude")
            case attitudeTag:
                out.roll = doubleAttr(el, "roll")
                out.pitch = doubleAttr(el, "pitch")
                out.yaw = doubleAttr(el, "yaw")
            default:
                break
            }
        }

        let hasSensor =
            out.accelerometerX != nil || out.accelerometerY != nil || out.accelerometerZ != nil
            || out.gyroscopeX != nil || out.pressureKPa != nil || out.relativeAltitudeMeters != nil
            || out.roll != nil || out.pitch != nil || out.yaw != nil
        return hasSensor ? out : nil
    }

    private static func doubleAttr(_ el: GPXExtensionsElement, _ key: String) -> Double? {
        guard let s = el.attributes[key] else { return nil }
        return Double(s)
    }
}
