//
//  GPXAnalysisModels.swift
//  OpenGpxTracker
//
//  Types for offline GPX + sensor analysis (no map).
//

import Foundation

/// One track point after analysis, aligned with optional sensor snapshot from GPX extensions.
struct GPXAnalysisPoint {
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let timestamp: Date?

    /// Seconds since previous point; 0 for first.
    let deltaTime: Double
    /// Haversine distance from previous point (m).
    let distance: Double
    let cumulativeDistance: Double
    /// Seconds from first point in this analyzed window.
    let elapsedTime: Double

    let speedHaversine: Double
    let speedSmoothed: Double
    /// Haversine-based unless GPX carries an extension speed (m/s).
    let speedFinal: Double
    /// Approximate longitudinal acceleration in g (Δspeed / Δt / g₀).
    let accelerationG: Double
    /// Percent grade (100 * rise / run).
    let grade: Double
    /// Vertical speed m/s from GPS elevation deltas.
    let verticalSpeed: Double
    /// Minutes per kilometer when speed > 0.2 m/s; otherwise nil.
    let paceMinPerKm: Double?

    let sensor: SensorSnapshot?

    let accelerationMagnitude: Double?
    let dynamicAcceleration: Double?
    let vibrationIndex: Double?
    let barometricVerticalSpeed: Double?
}

struct GPXAnalysisSummary {
    let distanceMeters: Double
    let durationSeconds: Double
    let averageSpeedMps: Double
    let maxSpeedMps: Double
    let elevationGainMeters: Double
    let minElevationMeters: Double?
    let maxElevationMeters: Double?
    /// Average pace min/km when distance > 0.
    let averagePaceMinPerKm: Double?

    let maxDynamicAcceleration: Double?
    let averageVibrationIndex: Double?
    let pressureMinKPa: Double?
    let pressureMaxKPa: Double?
    let relativeAltitudeMinM: Double?
    let relativeAltitudeMaxM: Double?
}

struct GPXDataQualityMetrics {
    let gpsGapCount: Int
    let maxTimeGapSeconds: Double
    let speedSpikeCount: Int
    let sensorSnapshotCount: Int
    let sensorCoveragePercent: Double
}

struct GPXAnalysisResult {
    let points: [GPXAnalysisPoint]
    let summary: GPXAnalysisSummary
    let quality: GPXDataQualityMetrics
}
