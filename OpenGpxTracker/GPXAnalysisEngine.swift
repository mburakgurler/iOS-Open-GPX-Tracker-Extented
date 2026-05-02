//
//  GPXAnalysisEngine.swift
//  OpenGpxTracker
//
//  Haversine-based metrics and optional sensor-derived series (computed when analysis opens).
//

import Foundation
import CoreGPX

enum GPXAnalysisEngine {

    private static let earthRadiusMeters = 6_371_000.0
    private static let gravityMps2 = 9.80665
    private static let gapThresholdSeconds = 60.0
    private static let speedSpikeMps = 50.0
    private static let smoothingAlpha = 0.25
    private static let vibrationWindow = 7

    /// Flattens all track segments in document order, then route points, then waypoints if no track data.
    static func collectTrackPoints(from root: GPXRoot) -> [GPXTrackPoint] {
        var out: [GPXTrackPoint] = []
        for track in root.tracks {
            for segment in track.segments {
                out.append(contentsOf: segment.points)
            }
        }
        if out.isEmpty {
            for route in root.routes {
                for rp in route.points {
                    out.append(trackPoint(from: rp))
                }
            }
        }
        if out.isEmpty {
            for w in root.waypoints {
                out.append(trackPoint(from: w))
            }
        }
        return out
    }

    private static func trackPoint(from waypoint: GPXWaypoint) -> GPXTrackPoint {
        let p = GPXTrackPoint()
        p.latitude = waypoint.latitude
        p.longitude = waypoint.longitude
        p.elevation = waypoint.elevation
        p.time = waypoint.time
        p.extensions = waypoint.extensions
        return p
    }

    static func analyze(trackPoints: [GPXTrackPoint]) -> GPXAnalysisResult {
        guard !trackPoints.isEmpty else {
            return GPXAnalysisResult(
                points: [],
                summary: emptySummary(),
                quality: GPXDataQualityMetrics(
                    gpsGapCount: 0,
                    maxTimeGapSeconds: 0,
                    speedSpikeCount: 0,
                    sensorSnapshotCount: 0,
                    sensorCoveragePercent: 0
                )
            )
        }

        var rows: [GPXAnalysisPoint] = []
        rows.reserveCapacity(trackPoints.count)

        var cumulative: Double = 0
        var elapsed: Double = 0
        var prevLat: Double?
        var prevLon: Double?
        var prevEle: Double?
        var prevTime: Date?
        var prevSpeedForAccel: Double = 0
        var prevSpeedSmoothed: Double = 0
        var gpsGaps = 0
        var maxGap: Double = 0
        var speedSpikes = 0
        var sensorSnapshots = 0
        var dynAccelSeries: [Double] = []

        for pt in trackPoints {
            let lat = pt.latitude ?? 0
            let lon = pt.longitude ?? 0
            let ele = pt.elevation
            let time = pt.time
            let sensor = GPXSensorExtensionParser.sensorSnapshot(from: pt)
            if sensor != nil { sensorSnapshots += 1 }

            guard let pLat = prevLat, let pLon = prevLon else {
                rows.append(
                    makePoint(
                        lat: lat, lon: lon, ele: ele, time: time, sensor: sensor,
                        deltaTime: 0, dist: 0, cumulative: 0, elapsed: 0,
                        speedH: 0, speedSmoothed: 0, speedFinal: 0,
                        accelG: 0, grade: 0, vertSpeed: 0, pace: nil,
                        accMag: nil, dynAcc: nil, vib: nil, baroVS: nil
                    )
                )
                dynAccelSeries.append(0)
                prevLat = lat
                prevLon = lon
                prevEle = ele
                prevTime = time
                prevSpeedForAccel = 0
                prevSpeedSmoothed = 0
                continue
            }

            var deltaTime: Double = 0
            if let t0 = prevTime, let t1 = time {
                deltaTime = t1.timeIntervalSince(t0)
                if deltaTime > gapThresholdSeconds {
                    gpsGaps += 1
                    maxGap = max(maxGap, deltaTime)
                }
            }

            let dist = haversineMeters(lat1: pLat, lon1: pLon, lat2: lat, lon2: lon)
            var speedH: Double = 0
            if deltaTime > 0.05 {
                speedH = dist / deltaTime
            }
            if speedH > speedSpikeMps {
                speedSpikes += 1
            }

            var grade: Double = 0
            var vertSpeed: Double = 0
            if let e0 = prevEle, let e1 = ele, deltaTime > 0.05 {
                let de = e1 - e0
                vertSpeed = de / deltaTime
                let horiz = max(sqrt(max(0, dist * dist - de * de)), 0.5)
                grade = (de / horiz) * 100.0
            }

            let extSpeed = gpxExtensionSpeedMetersPerSecond(from: pt.extensions)
            let speedFinal: Double
            if let es = extSpeed, es >= 0, es < speedSpikeMps {
                speedFinal = es
            } else {
                speedFinal = speedH
            }

            let speedSmoothed = smoothingAlpha * speedFinal + (1 - smoothingAlpha) * prevSpeedSmoothed

            var accelG: Double = 0
            if deltaTime > 0.05 {
                accelG = (speedSmoothed - prevSpeedForAccel) / deltaTime / gravityMps2
            }
            prevSpeedForAccel = speedSmoothed
            prevSpeedSmoothed = speedSmoothed

            cumulative += dist
            if deltaTime > 0 {
                elapsed += deltaTime
            }

            let pace: Double? = speedSmoothed > 0.2 ? (1000.0 / speedSmoothed) / 60.0 : nil

            let prevPt = rows.last
            let prevSensor = prevPt?.sensor
            let (accMag, dynAcc, baroVS) = sensorDerived(
                sensor: sensor,
                prevSensor: prevSensor,
                deltaTime: deltaTime
            )
            if let d = dynAcc {
                dynAccelSeries.append(d)
            } else {
                dynAccelSeries.append(0)
            }
            let vib = movingAverageLast(dynAccelSeries, window: vibrationWindow)

            rows.append(
                makePoint(
                    lat: lat, lon: lon, ele: ele, time: time, sensor: sensor,
                    deltaTime: deltaTime, dist: dist, cumulative: cumulative, elapsed: elapsed,
                    speedH: speedH, speedSmoothed: speedSmoothed, speedFinal: speedFinal,
                    accelG: accelG, grade: grade, vertSpeed: vertSpeed, pace: pace,
                    accMag: accMag, dynAcc: dynAcc, vib: vib, baroVS: baroVS
                )
            )

            prevLat = lat
            prevLon = lon
            prevEle = ele
            prevTime = time
        }

        let summary = buildSummary(from: rows)
        let coverage = (Double(sensorSnapshots) / Double(trackPoints.count)) * 100.0
        let quality = GPXDataQualityMetrics(
            gpsGapCount: gpsGaps,
            maxTimeGapSeconds: maxGap,
            speedSpikeCount: speedSpikes,
            sensorSnapshotCount: sensorSnapshots,
            sensorCoveragePercent: coverage
        )

        return GPXAnalysisResult(points: rows, summary: summary, quality: quality)
    }

    private static func makePoint(
        lat: Double, lon: Double, ele: Double?, time: Date?, sensor: SensorSnapshot?,
        deltaTime: Double, dist: Double, cumulative: Double, elapsed: Double,
        speedH: Double, speedSmoothed: Double, speedFinal: Double,
        accelG: Double, grade: Double, vertSpeed: Double, pace: Double?,
        accMag: Double?, dynAcc: Double?, vib: Double?, baroVS: Double?
    ) -> GPXAnalysisPoint {
        GPXAnalysisPoint(
            latitude: lat,
            longitude: lon,
            elevation: ele,
            timestamp: time,
            deltaTime: deltaTime,
            distance: dist,
            cumulativeDistance: cumulative,
            elapsedTime: elapsed,
            speedHaversine: speedH,
            speedSmoothed: speedSmoothed,
            speedFinal: speedFinal,
            accelerationG: accelG,
            grade: grade,
            verticalSpeed: vertSpeed,
            paceMinPerKm: pace,
            sensor: sensor,
            accelerationMagnitude: accMag,
            dynamicAcceleration: dynAcc,
            vibrationIndex: vib,
            barometricVerticalSpeed: baroVS
        )
    }

    private static func emptySummary() -> GPXAnalysisSummary {
        GPXAnalysisSummary(
            distanceMeters: 0,
            durationSeconds: 0,
            averageSpeedMps: 0,
            maxSpeedMps: 0,
            elevationGainMeters: 0,
            minElevationMeters: nil,
            maxElevationMeters: nil,
            averagePaceMinPerKm: nil,
            maxDynamicAcceleration: nil,
            averageVibrationIndex: nil,
            pressureMinKPa: nil,
            pressureMaxKPa: nil,
            relativeAltitudeMinM: nil,
            relativeAltitudeMaxM: nil
        )
    }

    private static func buildSummary(from rows: [GPXAnalysisPoint]) -> GPXAnalysisSummary {
        guard let last = rows.last else { return emptySummary() }

        var elevGain: Double = 0
        var minE: Double?
        var maxE: Double?
        var prevE: Double?
        var maxSpeed: Double = 0
        var maxDyn: Double?
        var vibSum: Double = 0
        var vibCount = 0
        var pMin: Double?
        var pMax: Double?
        var relMin: Double?
        var relMax: Double?

        for r in rows {
            maxSpeed = max(maxSpeed, r.speedSmoothed)
            if let e = r.elevation {
                minE = minE.map { min($0, e) } ?? e
                maxE = maxE.map { max($0, e) } ?? e
                if let p0 = prevE {
                    elevGain += max(0, e - p0)
                }
                prevE = e
            }
            if let d = r.dynamicAcceleration {
                maxDyn = maxDyn.map { max($0, d) } ?? d
            }
            if let v = r.vibrationIndex {
                vibSum += v
                vibCount += 1
            }
            if let p = r.sensor?.pressureKPa {
                pMin = pMin.map { min($0, p) } ?? p
                pMax = pMax.map { max($0, p) } ?? p
            }
            if let rel = r.sensor?.relativeAltitudeMeters {
                relMin = relMin.map { min($0, rel) } ?? rel
                relMax = relMax.map { max($0, rel) } ?? rel
            }
        }

        let dur = last.elapsedTime
        let dist = last.cumulativeDistance
        let avgSpeed = dur > 0 ? dist / dur : 0
        let avgPace: Double? = dist > 1 && dur > 0 ? (dur / 60.0) / (dist / 1000.0) : nil

        return GPXAnalysisSummary(
            distanceMeters: dist,
            durationSeconds: dur,
            averageSpeedMps: avgSpeed,
            maxSpeedMps: maxSpeed,
            elevationGainMeters: elevGain,
            minElevationMeters: minE,
            maxElevationMeters: maxE,
            averagePaceMinPerKm: avgPace,
            maxDynamicAcceleration: maxDyn,
            averageVibrationIndex: vibCount > 0 ? vibSum / Double(vibCount) : nil,
            pressureMinKPa: pMin,
            pressureMaxKPa: pMax,
            relativeAltitudeMinM: relMin,
            relativeAltitudeMaxM: relMax
        )
    }

    private static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let rlat1 = lat1 * .pi / 180
        let rlat2 = lat2 * .pi / 180
        let dlat = (lat2 - lat1) * .pi / 180
        let dlon = (lon2 - lon1) * .pi / 180
        let a = sin(dlat / 2) * sin(dlat / 2)
            + cos(rlat1) * cos(rlat2) * sin(dlon / 2) * sin(dlon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    /// Best-effort speed from generic GPX extensions (m/s).
    private static func gpxExtensionSpeedMetersPerSecond(from extensions: GPXExtensions?) -> Double? {
        guard let children = extensions?.children else { return nil }
        return searchSpeed(in: children)
    }

    private static func searchSpeed(in elements: [GPXExtensionsElement]) -> Double? {
        for el in elements {
            let name = el.name.lowercased()
            if name == "speed" || name.hasSuffix(":speed") {
                if let t = el.text, let v = Double(t) { return v }
                if let a = el.attributes["value"], let v = Double(a) { return v }
            }
            if let nested = searchSpeed(in: el.children) {
                return nested
            }
        }
        return nil
    }

    private static func sensorDerived(
        sensor: SensorSnapshot?,
        prevSensor: SensorSnapshot?,
        deltaTime: Double
    ) -> (magnitude: Double?, dynamic: Double?, baroVS: Double?) {
        let baro = barometricVerticalSpeed(sensor: sensor, prev: prevSensor, deltaTime: deltaTime)
        guard let s = sensor,
              let x = s.accelerometerX,
              let y = s.accelerometerY,
              let z = s.accelerometerZ else {
            return (nil, nil, baro)
        }
        let mag = sqrt(x * x + y * y + z * z)
        let dyn = abs(mag - 1.0)
        return (mag, dyn, baro)
    }

    private static func barometricVerticalSpeed(
        sensor: SensorSnapshot?,
        prev: SensorSnapshot?,
        deltaTime: Double
    ) -> Double? {
        guard let s = sensor?.relativeAltitudeMeters,
              let p0 = prev?.relativeAltitudeMeters,
              deltaTime > 0.05 else { return nil }
        return (s - p0) / deltaTime
    }

    private static func movingAverageLast(_ series: [Double], window: Int) -> Double? {
        guard !series.isEmpty else { return nil }
        let n = min(window, series.count)
        let slice = series.suffix(n)
        return slice.reduce(0, +) / Double(n)
    }
}
