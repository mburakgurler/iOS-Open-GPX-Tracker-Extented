//
//  GPXTileServer.swift
//  OpenGpxTracker
//
//  Created by merlos on 25/01/15.
//
// Shared file: this file is also included in the OpenGpxTracker-Watch Extension target.

import Foundation

/// Whether a raster map provider needs an API key (stored separately).
enum MapProviderKeyRequirement: Int {
    case none
    case mapTiler
    case stadia
    case thunderforest
    case jawg

    /// UserDefaults key for the API token (iOS); `nil` when not applicable.
    var storageKey: String? {
        switch self {
        case .none: return nil
        case .mapTiler: return "MapProviderAPIKey.mapTiler"
        case .stadia: return "MapProviderAPIKey.stadia"
        case .thunderforest: return "MapProviderAPIKey.thunderforest"
        case .jawg: return "MapProviderAPIKey.jawg"
        }
    }
}

///
/// Configuration for supported tile servers.
///
/// Maps displayed in the application are sets of small square images caled tiles. There are different servers that
/// provide these tiles.
///
/// A tile server is defined by an internal id (for instance .openStreetMap), a name string for displaying
/// on the interface and a URL template.
///
enum GPXTileServer: Int {
    
    /// Apple tile server
    case apple = 0
    
    /// Apple satellite tile server
    case appleSatellite = 1
    
    /// OpenStreetMap tile server
    case openStreetMap = 2
    // case AnotherMap
    
    /// CartoDB tile server
    case cartoDB = 3
    
    /// CartoDB tile server (2x tiles)
    case cartoDBRetina = 4
    
    /// OpenTopoMap tile server
    case openTopoMap = 5
    
    /// OpenSeaMap tile server
    case openSeaMap = 6

    /// CartoDB Positron (light basemap)
    case cartoDBPositron = 7

    /// CartoDB Dark Matter
    case cartoDBDarkMatter = 8

    /// OpenStreetMap Humanitarian (HOT) style
    case openStreetMapHumanitarian = 9

    /// MapTiler Streets (API key required)
    case mapTilerStreets = 10

    /// Stadia Alidade Smooth (API key required)
    case stadiaAlidadeSmooth = 11

    /// Thunderforest Outdoors (API key required)
    case thunderforestOutdoors = 12
    
    /// String that describes the selected tile server.
    var name: String {
        switch self {
        case .apple: return "Apple Mapkit (no offline cache)"
        case .appleSatellite: return "Apple Satellite (no offline cache)"
        case .openStreetMap: return "OpenStreetMap"
        case .cartoDB: return "Carto DB"
        case .cartoDBRetina: return "Carto DB (Retina resolution)"
        case .openTopoMap: return "OpenTopoMap"
        case .openSeaMap: return "OpenSeaMap"
        case .cartoDBPositron: return "CartoDB Positron"
        case .cartoDBDarkMatter: return "CartoDB Dark Matter"
        case .openStreetMapHumanitarian: return "OpenStreetMap Humanitarian"
        case .mapTilerStreets: return "MapTiler Streets"
        case .stadiaAlidadeSmooth: return "Stadia Alidade Smooth"
        case .thunderforestOutdoors: return "Thunderforest Outdoors"
        }
    }

    /// Third-party attribution (empty for Apple MapKit).
    var mapAttribution: String {
        switch self {
        case .apple, .appleSatellite:
            return ""
        case .openStreetMap, .openStreetMapHumanitarian:
            return "© OpenStreetMap contributors"
        case .cartoDB, .cartoDBRetina, .cartoDBPositron, .cartoDBDarkMatter:
            return "© OpenStreetMap contributors © CARTO"
        case .openTopoMap:
            return "© OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)"
        case .openSeaMap:
            return "© OpenSeaMap contributors"
        case .mapTilerStreets:
            return "© MapTiler © OpenStreetMap contributors"
        case .stadiaAlidadeSmooth:
            return "© Stadia Maps © OpenMapTiles © OpenStreetMap contributors"
        case .thunderforestOutdoors:
            return "Maps © Thunderforest, Data © OpenStreetMap contributors"
        }
    }

    /// API key policy for this tile server.
    var keyRequirement: MapProviderKeyRequirement {
        switch self {
        case .mapTilerStreets:
            return .mapTiler
        case .stadiaAlidadeSmooth:
            return .stadia
        case .thunderforestOutdoors:
            return .thunderforest
        default:
            return .none
        }
    }
    
    /// URL template of current tile server (it is of the form http://{s}.map.tile.server/{z}/{x}/{y}.png
    var templateUrl: String {
        switch self {
        case .apple: return ""
        case .appleSatellite: return ""
        case .openStreetMap: return "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        case .cartoDB: return "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png"
        case .cartoDBRetina: return "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png"
        case .openTopoMap: return "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png"
        case .openSeaMap: return "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png"
        case .cartoDBPositron:
            return "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"
        case .cartoDBDarkMatter:
            return "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
        case .openStreetMapHumanitarian:
            return "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png"
        case .mapTilerStreets:
            return "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key={apiKey}"
        case .stadiaAlidadeSmooth:
            return "https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={apiKey}"
        case .thunderforestOutdoors:
            return "https://api.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey={apiKey}"
        }
    }
    
    /// In the `templateUrl` the {s} means subdomain, typically the subdomains available are a,b and c
    /// Check the subdomains available for your server.
    ///
    /// Set an empty array (`[]`) in case you don't use `{s}` in your `templateUrl`.
    ///
    /// Subdomains is useful to distribute the tile request download among the diferent servers
    /// and displaying them faster as result.
    var subdomains: [String] {
        switch self {
        case .apple: return []
        case .appleSatellite: return []
        case .openStreetMap: return ["a", "b", "c"]
        case .cartoDB, .cartoDBRetina, .cartoDBPositron, .cartoDBDarkMatter: return ["a", "b", "c"]
        case .openTopoMap: return ["a", "b", "c"]
        case .openStreetMapHumanitarian: return ["a", "b", "c"]
        case .openSeaMap: return []
        case .mapTilerStreets, .stadiaAlidadeSmooth, .thunderforestOutdoors:
            return []
        // case .AnotherMap: return ["a","b"]
        }
    }
    
    /// Maximum zoom level the tile server supports
    /// Tile servers provide files till a certain level of zoom that ranges from 0 to maximumZ.
    /// If map zooms more than the limit level, tiles won't be requested.
    ///
    ///  Typically the value is around 19,20 or 21.
    ///
    ///  Use negative to avoid setting a limit.
    ///
    /// - see https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Tile_servers
    ///
    var maximumZ: Int {
        switch self {
        case .apple:
            return -1
        case .appleSatellite: 
            return -1
        case .openStreetMap:
            return 19
        case .cartoDB, .cartoDBRetina:
            return 21
        case .openTopoMap:
            return 17
        // case .AnotherMap: return 10
        case .openSeaMap:
            return 16
        case .cartoDBPositron, .cartoDBDarkMatter:
            return 20
        case .openStreetMapHumanitarian:
            return 19
        case .mapTilerStreets:
            return 22
        case .stadiaAlidadeSmooth:
            return 20
        case .thunderforestOutdoors:
            return 22
        }
    }
    ///
    /// Minimum zoom supported by the tile server
    ///
    /// This limits the tiles requested based on current zoom level.
    /// No tiles will be requested for zooms levels lower that this.
    ///
    /// Needs to be 0 or larger.
    ///
    var minimumZ: Int {
        switch self {
        case .apple:
            return 0
        case .appleSatellite:
            return 0
        case .openStreetMap:
            return 0
        case .cartoDB, .cartoDBRetina:
            return 0
        case .openTopoMap:
            return 0
        case .openSeaMap:
            return 0
        case .cartoDBPositron, .cartoDBDarkMatter, .openStreetMapHumanitarian,
             .mapTilerStreets, .stadiaAlidadeSmooth, .thunderforestOutdoors:
            return 0
        // case .AnotherMap: return 0
        }
    }
    
    /// Does the tile overlay replace the map?
    ///  Generally all the tiles provided replace the AppleMaps. However there are some
    var canReplaceMapContent: Bool {
        switch self {
        case .openSeaMap: return false
        default: return true
        }
    }
    
    /// tile size of the third-party tile.
    /// 
    /// 1x tiles are 256x256
    /// 2x/retina tiles are 512x512
    var tileSize: Int {
        switch self {
        case .cartoDBRetina: return 512
        default: return 256
        }
    }
    
    /// Defines the color mode for the tile server
    enum GPXTileServerColorMode {
        case lightMode
        case system
        case darkMode
    }
    
    /// Returns the color mode for the tile server
    var colorMode: GPXTileServerColorMode {
        switch self {
        case .apple: return .system
        case .appleSatellite: return .darkMode
        case .cartoDBDarkMatter: return .darkMode
        case .cartoDB, .cartoDBRetina, .cartoDBPositron, .openTopoMap, .openSeaMap, .openStreetMap,
             .openStreetMapHumanitarian, .mapTilerStreets, .stadiaAlidadeSmooth, .thunderforestOutdoors:
            return .lightMode
        }
    }

    /// Returns the number of tile servers currently defined
    static var count: Int { GPXTileServer.thunderforestOutdoors.rawValue + 1 }
}

#if os(iOS)
extension GPXTileServer {

    /// If the user chose a key-based provider but no key is stored, fall back to Apple Maps.
    func withFallbackWhenApiKeyMissing() -> GPXTileServer {
        let req = keyRequirement
        guard req != .none, let key = req.storageKey else { return self }
        let value = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return .apple }
        return self
    }
}
#endif
