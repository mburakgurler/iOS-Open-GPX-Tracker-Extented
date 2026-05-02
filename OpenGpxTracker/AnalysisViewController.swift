//
//  AnalysisViewController.swift
//  OpenGpxTracker
//
//  Modal analysis of a GPX file: stats + simple charts (no map, no live tracking).
//

import UIKit
import CoreGPX

final class AnalysisViewController: UIViewController {

    private let fileURL: URL
    private let displayTitle: String

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        }
        return UIActivityIndicatorView(style: .gray)
    }()
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .red
        l.numberOfLines = 0
        l.isHidden = true
        l.textAlignment = .center
        return l
    }()

    private var allTrackPoints: [GPXTrackPoint] = []
    private var result: GPXAnalysisResult?

    private let startSlider = UISlider()
    private let endSlider = UISlider()
    private let rangeLabel = UILabel()
    private let applyRangeButton = UIButton(type: .system)
    private let resetRangeButton = UIButton(type: .system)

    private var chartHostStack: UIStackView?

    init(fileURL: URL, displayTitle: String) {
        self.fileURL = fileURL
        self.displayTitle = displayTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.backgroundCompatible
        title = displayTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        configureRangeControls()
        loadGPXAsync()
    }

    private func configureRangeControls() {
        startSlider.minimumValue = 0
        startSlider.maximumValue = 1
        startSlider.value = 0
        endSlider.minimumValue = 0
        endSlider.maximumValue = 1
        endSlider.value = 1

        startSlider.addTarget(self, action: #selector(rangeSliderChanged), for: .valueChanged)
        endSlider.addTarget(self, action: #selector(rangeSliderChanged), for: .valueChanged)

        applyRangeButton.setTitle(NSLocalizedString("ANALYSIS_APPLY_RANGE", comment: ""), for: .normal)
        applyRangeButton.addTarget(self, action: #selector(applyRangeTapped), for: .touchUpInside)

        resetRangeButton.setTitle(NSLocalizedString("ANALYSIS_RESET_RANGE", comment: ""), for: .normal)
        resetRangeButton.addTarget(self, action: #selector(resetRangeTapped), for: .touchUpInside)

        rangeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        rangeLabel.numberOfLines = 2
        rangeLabel.textAlignment = .center
        rangeLabel.textColor = UIColor.secondaryLabelCompatible
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    @objc private func rangeSliderChanged() {
        normalizeRangeSliders()
        updateRangeLabel()
    }

    @objc private func applyRangeTapped() {
        guard !allTrackPoints.isEmpty else { return }
        normalizeRangeSliders()
        let n = allTrackPoints.count
        let si = indexFromSlider(startSlider.value, maxIndex: n - 1)
        let ei = indexFromSlider(endSlider.value, maxIndex: n - 1)
        let lo = min(si, ei)
        let hi = max(si, ei)
        let slice = Array(allTrackPoints[lo...hi])
        result = GPXAnalysisEngine.analyze(trackPoints: slice)
        rebuildCharts()
    }

    @objc private func resetRangeTapped() {
        startSlider.value = 0
        endSlider.value = 1
        updateRangeLabel()
        result = GPXAnalysisEngine.analyze(trackPoints: allTrackPoints)
        rebuildCharts()
    }

    private func indexFromSlider(_ v: Float, maxIndex: Int) -> Int {
        guard maxIndex > 0 else { return 0 }
        return min(maxIndex, Int(round(Double(v) * Double(maxIndex))))
    }

    private func normalizeRangeSliders() {
        if startSlider.value > endSlider.value {
            let a = startSlider.value
            startSlider.value = endSlider.value
            endSlider.value = a
        }
    }

    private func updateRangeLabel() {
        guard !allTrackPoints.isEmpty else {
            rangeLabel.text = ""
            return
        }
        let n = allTrackPoints.count
        let si = indexFromSlider(startSlider.value, maxIndex: n - 1)
        let ei = indexFromSlider(endSlider.value, maxIndex: n - 1)
        let lo = min(si, ei)
        let hi = max(si, ei)
        let t0 = allTrackPoints[lo].time
        let t1 = allTrackPoints[hi].time
        let df = DateFormatter()
        df.timeStyle = .medium
        df.dateStyle = .none
        let a = t0.map { df.string(from: $0) } ?? "—"
        let b = t1.map { df.string(from: $0) } ?? "—"
        rangeLabel.text = String(format: NSLocalizedString("ANALYSIS_RANGE_TIMES", comment: ""), a, b)
    }

    private func loadGPXAsync() {
        loadingIndicator.startAnimating()
        errorLabel.isHidden = true
        let url = fileURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let folderURL = GPXFileManager.GPXFilesFolderURL
            let secured = folderURL.startAccessingSecurityScopedResource()
            if secured {
                defer { folderURL.stopAccessingSecurityScopedResource() }
            }
            let root = GPXFileParseSupport.parseRoot(fromFileURL: url)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                guard let gpx = root else {
                    self.errorLabel.text = NSLocalizedString("ANALYSIS_LOAD_FAILED", comment: "")
                    self.errorLabel.isHidden = false
                    return
                }
                self.allTrackPoints = GPXAnalysisEngine.collectTrackPoints(from: gpx)
                if self.allTrackPoints.isEmpty {
                    self.errorLabel.text = NSLocalizedString("ANALYSIS_NO_TRACK_POINTS", comment: "")
                    self.errorLabel.isHidden = false
                    return
                }
                self.result = GPXAnalysisEngine.analyze(trackPoints: self.allTrackPoints)
                self.startSlider.value = 0
                self.endSlider.value = 1
                self.updateRangeLabel()
                self.buildContent()
            }
        }
    }

    private func buildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let imperial = Preferences.shared.useImperial

        if let summary = result?.summary, let quality = result?.quality {
            contentStack.addArrangedSubview(sectionLabel(NSLocalizedString("ANALYSIS_SECTION_SUMMARY", comment: "")))
            contentStack.addArrangedSubview(statsSummaryBlock(summary: summary, quality: quality, imperial: imperial))

            contentStack.addArrangedSubview(sectionLabel(NSLocalizedString("ANALYSIS_SECTION_RANGE", comment: "")))
            contentStack.addArrangedSubview(rangeControlsCard())

            let chartStack = UIStackView()
            chartStack.axis = .vertical
            chartStack.spacing = 28
            chartHostStack = chartStack
            contentStack.addArrangedSubview(sectionLabel(NSLocalizedString("ANALYSIS_SECTION_CHARTS", comment: "")))
            contentStack.addArrangedSubview(chartStack)

            rebuildCharts()
        }
    }

    private func rebuildCharts() {
        chartHostStack?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let pts = result?.points, !pts.isEmpty, let host = chartHostStack else { return }

        let imperial = Preferences.shared.useImperial

        let speedSeries: [Double] = pts.map { pt in
            if imperial {
                return pt.speedSmoothed * kMilesPerHourInOneMeterPerSecond
            }
            return pt.speedSmoothed * kKilometersPerHourInOneMeterPerSecond
        }
        host.addArrangedSubview(
            chartSection(
                title: NSLocalizedString("ANALYSIS_CHART_SPEED", comment: ""),
                subtitle: imperial ? "mph" : "km/h",
                values: speedSeries,
                accent: chartAccentColor(index: 0)
            )
        )

        let elevSeries: [Double] = pts.map { pt in
            guard let e = pt.elevation else { return Double.nan }
            return imperial ? e / kMetersPerFeet : e
        }
        host.addArrangedSubview(
            chartSection(
                title: NSLocalizedString("ANALYSIS_CHART_ELEVATION", comment: ""),
                subtitle: imperial ? "ft" : "m",
                values: elevSeries,
                accent: chartAccentColor(index: 1)
            )
        )

        host.addArrangedSubview(
            chartSection(
                title: NSLocalizedString("ANALYSIS_CHART_GRADE", comment: ""),
                subtitle: "%",
                values: pts.map { $0.grade },
                accent: chartAccentColor(index: 2)
            )
        )

        let accMag = pts.map { $0.accelerationMagnitude ?? Double.nan }
        if accMag.contains(where: { !$0.isNaN }) {
            host.addArrangedSubview(
                chartSection(
                    title: NSLocalizedString("ANALYSIS_CHART_ACCEL_MAG", comment: ""),
                    subtitle: "g",
                    values: accMag,
                    accent: chartAccentColor(index: 3)
                )
            )
        }

        let relAlt = pts.map { $0.sensor?.relativeAltitudeMeters ?? Double.nan }
        if relAlt.contains(where: { !$0.isNaN }) {
            host.addArrangedSubview(
                chartSection(
                    title: NSLocalizedString("ANALYSIS_CHART_REL_ALTITUDE", comment: ""),
                    subtitle: "m",
                    values: relAlt,
                    accent: chartAccentColor(index: 4)
                )
            )
        }

        let vib = pts.map { $0.vibrationIndex ?? Double.nan }
        if vib.contains(where: { !$0.isNaN }) {
            host.addArrangedSubview(
                chartSection(
                    title: NSLocalizedString("ANALYSIS_CHART_VIBRATION", comment: ""),
                    subtitle: "g",
                    values: vib,
                    accent: chartAccentColor(index: 5)
                )
            )
        }
    }

    private func chartAccentColor(index: Int) -> UIColor {
        if #available(iOS 13.0, *) {
            let palette: [UIColor] = [
                .systemBlue, .systemGreen, .systemOrange,
                .systemPurple, .systemTeal, .systemPink
            ]
            return palette[index % palette.count]
        }
        let legacy: [UIColor] = [
            UIColor(red: 0, green: 0.48, blue: 1, alpha: 1),
            UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1),
            UIColor(red: 1, green: 0.58, blue: 0, alpha: 1),
            UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1),
            UIColor(red: 0.35, green: 0.78, blue: 0.8, alpha: 1),
            UIColor(red: 0.35, green: 0.35, blue: 0.78, alpha: 1)
        ]
        return legacy[index % legacy.count]
    }

    private func chartSection(title: String, subtitle: String, values: [Double], accent: UIColor) -> UIView {
        let outer = UIStackView()
        outer.axis = .vertical
        outer.spacing = 8

        let cap = UILabel()
        let titleBase = UIFont.preferredFont(forTextStyle: .subheadline)
        cap.font = UIFont.systemFont(ofSize: titleBase.pointSize, weight: .semibold)
        cap.text = title
        cap.numberOfLines = 0
        if #available(iOS 13.0, *) {
            cap.textColor = .label
        } else {
            cap.textColor = .black
        }

        let unit = UILabel()
        unit.font = UIFont.preferredFont(forTextStyle: .caption1)
        unit.text = subtitle
        if #available(iOS 13.0, *) {
            unit.textColor = .secondaryLabel
        } else {
            unit.textColor = .darkGray
        }

        let rangeText = formattedValueRange(values)
        let rangeRow = UIStackView()
        rangeRow.axis = .horizontal
        rangeRow.distribution = .equalSpacing
        let lo = UILabel()
        let rangeFont: UIFont = {
            if #available(iOS 13.0, *) {
                return UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            }
            return UIFont.systemFont(ofSize: 11, weight: .medium)
        }()
        lo.font = rangeFont
        let hi = UILabel()
        hi.font = rangeFont
        if let parts = rangeText {
            lo.text = parts.low
            hi.text = parts.high
        } else {
            lo.text = ""
            hi.text = ""
        }
        if #available(iOS 13.0, *) {
            lo.textColor = .tertiaryLabel
            hi.textColor = .tertiaryLabel
        } else {
            lo.textColor = .gray
            hi.textColor = .gray
        }
        rangeRow.addArrangedSubview(lo)
        rangeRow.addArrangedSubview(hi)

        let chart = SimpleLineChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 188).isActive = true
        chart.series = values
        chart.accentColor = accent

        outer.addArrangedSubview(cap)
        outer.addArrangedSubview(unit)
        if rangeText != nil {
            outer.addArrangedSubview(rangeRow)
        }
        outer.addArrangedSubview(chart)
        return outer
    }

    private func formattedValueRange(_ values: [Double]) -> (low: String, high: String)? {
        let f = values.filter { $0.isFinite && !$0.isNaN }
        guard let a = f.min(), let b = f.max() else { return nil }
        let lo = min(a, b)
        let hi = max(a, b)
        if lo == hi, f.count < 2 { return nil }
        return (formatChartNumber(lo), formatChartNumber(hi))
    }

    private func formatChartNumber(_ x: Double) -> String {
        if abs(x) >= 1000 {
            return String(format: "%.0f", x)
        }
        if abs(x) >= 100 {
            return String(format: "%.1f", x)
        }
        return String(format: "%.2f", x)
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .headline)
        l.text = text
        l.numberOfLines = 0
        return l
    }

    private func subsectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.numberOfLines = 0
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        l.font = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        if #available(iOS 13.0, *) {
            l.textColor = .secondaryLabel
        } else {
            l.textColor = .darkGray
        }
        return l
    }

    private func statsSummaryBlock(summary: GPXAnalysisSummary, quality: GPXDataQualityMetrics, imperial: Bool) -> UIView {
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 18

        let trackPairs: [(String, String)] = [
            (NSLocalizedString("ANALYSIS_STAT_DISTANCE", comment: ""),
             summary.distanceMeters.toDistance(useImperial: imperial)),
            (NSLocalizedString("ANALYSIS_STAT_DURATION", comment: ""),
             formatDuration(summary.durationSeconds)),
            (NSLocalizedString("ANALYSIS_STAT_AVG_SPEED", comment: ""),
             summary.averageSpeedMps.toSpeed(useImperial: imperial)),
            (NSLocalizedString("ANALYSIS_STAT_MAX_SPEED", comment: ""),
             summary.maxSpeedMps.toSpeed(useImperial: imperial)),
            (NSLocalizedString("ANALYSIS_STAT_ELEV_GAIN", comment: ""),
             imperial
                ? String(format: "%.0fft", summary.elevationGainMeters / kMetersPerFeet)
                : String(format: "%.0fm", summary.elevationGainMeters)),
            (NSLocalizedString("ANALYSIS_STAT_MIN_ELEV", comment: ""),
             summary.minElevationMeters.map { $0.toAltitude(useImperial: imperial) } ?? "—"),
            (NSLocalizedString("ANALYSIS_STAT_MAX_ELEV", comment: ""),
             summary.maxElevationMeters.map { $0.toAltitude(useImperial: imperial) } ?? "—"),
            (NSLocalizedString("ANALYSIS_STAT_AVG_PACE", comment: ""),
             formatPace(summary.averagePaceMinPerKm))
        ]

        let sensorPairs: [(String, String)] = [
            (NSLocalizedString("ANALYSIS_STAT_MAX_DYN_ACCEL", comment: ""),
             summary.maxDynamicAcceleration.map { String(format: "%.3f g", $0) } ?? "—"),
            (NSLocalizedString("ANALYSIS_STAT_AVG_VIBRATION", comment: ""),
             summary.averageVibrationIndex.map { String(format: "%.3f", $0) } ?? "—"),
            (NSLocalizedString("ANALYSIS_STAT_PRESSURE_RANGE", comment: ""),
             formatPressureRange(min: summary.pressureMinKPa, max: summary.pressureMaxKPa)),
            (NSLocalizedString("ANALYSIS_STAT_REL_ALT_RANGE", comment: ""),
             formatRelAlt(min: summary.relativeAltitudeMinM, max: summary.relativeAltitudeMaxM))
        ]

        root.addArrangedSubview(subsectionLabel(NSLocalizedString("ANALYSIS_SUBSECTION_TRACK", comment: "")))
        root.addArrangedSubview(pairedMetricRows(trackPairs))

        root.addArrangedSubview(subsectionLabel(NSLocalizedString("ANALYSIS_SUBSECTION_SENSORS", comment: "")))
        root.addArrangedSubview(pairedMetricRows(sensorPairs))

        root.addArrangedSubview(subsectionLabel(NSLocalizedString("ANALYSIS_SUBSECTION_QUALITY", comment: "")))
        root.addArrangedSubview(qualityCard(quality: quality))

        return root
    }

    private func pairedMetricRows(_ pairs: [(String, String)]) -> UIStackView {
        let col = UIStackView()
        col.axis = .vertical
        col.spacing = 10
        var idx = 0
        while idx < pairs.count {
            if idx + 1 < pairs.count {
                let left = statCard(title: pairs[idx].0, value: pairs[idx].1)
                let right = statCard(title: pairs[idx + 1].0, value: pairs[idx + 1].1)
                let row = UIStackView(arrangedSubviews: [left, right])
                row.axis = .horizontal
                row.spacing = 10
                row.distribution = .fillEqually
                col.addArrangedSubview(row)
                idx += 2
            } else {
                col.addArrangedSubview(statCard(title: pairs[idx].0, value: pairs[idx].1))
                idx += 1
            }
        }
        return col
    }

    private func statCard(title: String, value: String) -> UIView {
        let wrap = UIView()
        wrap.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            wrap.layer.cornerCurve = .continuous
            wrap.backgroundColor = UIColor.secondarySystemGroupedBackground
        } else {
            wrap.backgroundColor = UIColor(white: 0.94, alpha: 1)
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        titleLabel.numberOfLines = 0
        if #available(iOS 13.0, *) {
            titleLabel.textColor = .secondaryLabel
        } else {
            titleLabel.textColor = .gray
        }

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        valueLabel.numberOfLines = 0
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65
        valueLabel.lineBreakMode = .byTruncatingTail
        if #available(iOS 13.0, *) {
            valueLabel.textColor = .label
        } else {
            valueLabel.textColor = .black
        }

        let inner = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        wrap.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: wrap.topAnchor),
            inner.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
        return wrap
    }

    private func qualityCard(quality: GPXDataQualityMetrics) -> UIView {
        let lines: [String] = [
            String(format: NSLocalizedString("ANALYSIS_QUALITY_GAPS", comment: ""), quality.gpsGapCount),
            String(format: NSLocalizedString("ANALYSIS_QUALITY_MAX_GAP", comment: ""), quality.maxTimeGapSeconds),
            String(format: NSLocalizedString("ANALYSIS_QUALITY_SPIKES", comment: ""), quality.speedSpikeCount),
            String(format: NSLocalizedString("ANALYSIS_QUALITY_SENSOR_COV", comment: ""), quality.sensorCoveragePercent)
        ]
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        for line in lines {
            let l = UILabel()
            l.font = UIFont.preferredFont(forTextStyle: .subheadline)
            l.text = line
            l.numberOfLines = 0
            if #available(iOS 13.0, *) {
                l.textColor = .label
            } else {
                l.textColor = .black
            }
            stack.addArrangedSubview(l)
        }
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        let card = UIView()
        card.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            card.layer.cornerCurve = .continuous
            card.backgroundColor = UIColor.secondarySystemGroupedBackground
        } else {
            card.backgroundColor = UIColor(white: 0.94, alpha: 1)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func rangeControlsCard() -> UIView {
        let rangeStack = UIStackView(arrangedSubviews: [rangeLabel, startSlider, endSlider])
        rangeStack.axis = .vertical
        rangeStack.spacing = 10

        let btnRow = UIStackView(arrangedSubviews: [applyRangeButton, resetRangeButton])
        btnRow.axis = .horizontal
        btnRow.spacing = 16
        btnRow.distribution = .fillEqually

        let inner = UIStackView(arrangedSubviews: [rangeStack, btnRow])
        inner.axis = .vertical
        inner.spacing = 14
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        let card = UIView()
        card.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            card.layer.cornerCurve = .continuous
            card.backgroundColor = UIColor.secondarySystemGroupedBackground
        } else {
            card.backgroundColor = UIColor(white: 0.94, alpha: 1)
        }
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func formatDuration(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, r)
        }
        return String(format: "%d:%02d", m, r)
    }

    private func formatPace(_ minPerKm: Double?) -> String {
        guard let p = minPerKm, p > 0, p.isFinite else { return "—" }
        let totalSec = Int((p * 60).rounded())
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d min/km", m, s)
    }

    private func formatPressureRange(min: Double?, max: Double?) -> String {
        guard let a = min, let b = max else { return "—" }
        return String(format: "%.2f – %.2f kPa", a, b)
    }

    private func formatRelAlt(min: Double?, max: Double?) -> String {
        guard let a = min, let b = max else { return "—" }
        return String(format: "%.1f – %.1f m", a, b)
    }
}

private extension UIColor {
    static var backgroundCompatible: UIColor {
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        return .white
    }

    static var secondaryLabelCompatible: UIColor {
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        return .gray
    }
}
