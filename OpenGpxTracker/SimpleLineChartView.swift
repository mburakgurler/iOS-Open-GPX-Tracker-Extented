//
//  SimpleLineChartView.swift
//  OpenGpxTracker
//
//  Lightweight line chart (UIKit, iOS 12+). No map dependency.
//

import UIKit

final class SimpleLineChartView: UIView {

    var series: [Double] = [] {
        didSet { setNeedsDisplay() }
    }

    /// Stroke and peak tint for the series line and fill.
    var accentColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemBlue
        }
        return UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
    }()

    private let cornerRadius: CGFloat = 12

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        contentMode = .redraw
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let panelFill: UIColor
        let gridStroke: UIColor
        if #available(iOS 13.0, *) {
            panelFill = UIColor.secondarySystemGroupedBackground.resolvedColor(with: traitCollection)
            gridStroke = UIColor.separator.resolvedColor(with: traitCollection).withAlphaComponent(0.55)
        } else {
            panelFill = UIColor(white: 0.94, alpha: 1)
            gridStroke = UIColor(white: 0.78, alpha: 1)
        }

        let pairs = series.enumerated().filter { $0.element.isFinite && !$0.element.isNaN }
        guard pairs.count >= 2 else {
            panelFill.setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).fill()
            return
        }
        let ys = pairs.map { $0.element }
        guard let minY = ys.min(), let maxY = ys.max() else { return }
        let span = max(maxY - minY, 1e-9)

        let bgPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        panelFill.setFill()
        bgPath.fill()

        let plot = bounds.insetBy(dx: 10, dy: 10)
        let h = max(plot.height, 1)
        let w = max(plot.width, 1)
        let denom = max(CGFloat(series.count - 1), 1)

        // Horizontal grid
        gridStroke.setStroke()
        for i in 0...4 {
            let t = CGFloat(i) / 4
            let y = plot.maxY - t * h
            let g = UIBezierPath()
            g.move(to: CGPoint(x: plot.minX, y: y))
            g.addLine(to: CGPoint(x: plot.maxX, y: y))
            g.lineWidth = i == 0 || i == 4 ? 0.75 : 0.5
            g.stroke()
        }

        var linePoints: [CGPoint] = []
        linePoints.reserveCapacity(pairs.count)
        for (idx, v) in pairs {
            let tx = CGFloat(idx) / denom
            let x = plot.minX + tx * w
            let ny = CGFloat((v - minY) / span)
            let y = plot.maxY - ny * h
            linePoints.append(CGPoint(x: x, y: y))
        }

        // Area under curve
        if linePoints.count >= 2 {
            let fillPath = UIBezierPath()
            fillPath.move(to: CGPoint(x: linePoints[0].x, y: plot.maxY))
            fillPath.addLine(to: linePoints[0])
            for p in linePoints.dropFirst() {
                fillPath.addLine(to: p)
            }
            fillPath.addLine(to: CGPoint(x: linePoints.last!.x, y: plot.maxY))
            fillPath.close()
            accentColor.withAlphaComponent(0.14).setFill()
            fillPath.fill()
        }

        let linePath = UIBezierPath()
        for (i, p) in linePoints.enumerated() {
            if i == 0 {
                linePath.move(to: p)
            } else {
                linePath.addLine(to: p)
            }
        }
        accentColor.setStroke()
        linePath.lineWidth = 2.25
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round
        linePath.stroke()
    }
}
