import Foundation

// MARK: - PlaceDetails
// Live shop data served by the worker from the Google Places API.
// Everything is optional-friendly: the detail screen falls back to the values
// stored in the database whenever a field is missing.

struct PlaceDetails: Codable, Hashable, Sendable {
    /// Google user rating, e.g. 4.6
    let rating: Double?
    /// Number of Google reviews behind the rating.
    let userRatingCount: Int?
    /// Whether the shop is open right now (from currentOpeningHours).
    let openNow: Bool?
    /// Weekly hours in the same shape the app already renders.
    let weekdayHours: [OpeningHours]
    /// Photo URLs served through the worker's photo proxy.
    let photos: [URL]
    /// Google Maps listing for the place.
    let googleMapsURI: String?
    /// The shop's own website, when Google knows it.
    let websiteURI: String?
}
