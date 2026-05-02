//
//  MapTileProviderSupport.swift
//  OpenGpxTracker
//
//  Map provider model, URL template resolution, and API key storage (iOS).
//

import Foundation

/// Describes a third-party raster map source (aligned with GPXTileServer extended cases).
struct MapTileProvider {
    let id: String
    let displayName: String
    let attribution: String
    let urlTemplate: String
    let keyRequirement: MapProviderKeyRequirement
    let maxZoom: Int
}

extension MapTileProvider {
    /// Key-based `GPXTileServer` cases only.
    init?(gpxTileServer: GPXTileServer) {
        guard gpxTileServer.keyRequirement != .none else { return nil }
        self.id = "gpx_tile_\(gpxTileServer.rawValue)"
        self.displayName = gpxTileServer.name
        self.attribution = gpxTileServer.mapAttribution
        self.urlTemplate = gpxTileServer.templateUrl
        self.keyRequirement = gpxTileServer.keyRequirement
        self.maxZoom = max(0, gpxTileServer.maximumZ)
    }
}

/// Builds tile URLs from a template with `{x}`, `{y}`, `{z}`, and optional `{apiKey}`.
final class MapProviderURLBuilder {

    func buildURL(tileServer: GPXTileServer, x: Int, y: Int, z: Int) -> URL? {
        guard let provider = MapTileProvider(gpxTileServer: tileServer) else { return nil }
        return buildURL(provider: provider, x: x, y: y, z: z)
    }

    func buildURL(provider: MapTileProvider, x: Int, y: Int, z: Int) -> URL? {
        var template = provider.urlTemplate
        template = template.replacingOccurrences(of: "{x}", with: "\(x)")
        template = template.replacingOccurrences(of: "{y}", with: "\(y)")
        template = template.replacingOccurrences(of: "{z}", with: "\(z)")
        if provider.keyRequirement != .none {
            guard let key = MapProviderAPIKeyStore.shared.apiKey(for: provider.keyRequirement)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.isEmpty else { return nil }
            template = template.replacingOccurrences(of: "{apiKey}", with: key)
        }
        return URL(string: template)
    }
}

/// Stores map provider API keys (UserDefaults for MVP).
final class MapProviderAPIKeyStore {

    static let shared = MapProviderAPIKeyStore()

    private let defaults = UserDefaults.standard

    private init() {}

    func apiKey(for requirement: MapProviderKeyRequirement) -> String? {
        guard let key = requirement.storageKey else { return nil }
        return defaults.string(forKey: key)
    }

    func setApiKey(_ value: String?, for requirement: MapProviderKeyRequirement) {
        guard let storageKey = requirement.storageKey else { return }
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            defaults.set(value, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    func hasStoredKey(for requirement: MapProviderKeyRequirement) -> Bool {
        guard let k = apiKey(for: requirement) else { return false }
        return !k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension GPXTileServer {

    /// Template string ready for `MapCache` / `MKTileOverlay`, or `nil` if an API key is missing.
    var resolvedTileURLTemplate: String? {
        if self == .apple || self == .appleSatellite {
            return nil
        }
        let base = templateUrl
        if keyRequirement == .none {
            return base.isEmpty ? nil : base
        }
        guard let key = MapProviderAPIKeyStore.shared.apiKey(for: keyRequirement)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return base.replacingOccurrences(of: "{apiKey}", with: key)
    }
}
