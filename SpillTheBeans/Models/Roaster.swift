import Foundation

// MARK: - Roaster
//
// Editorial metadata for the roasters whose beans appear in the encyclopedia.
// This is static content (curated from each roaster's own "about" page), so it
// lives in the app rather than the database. The beans themselves are still
// fetched live and matched to a roaster by `Coffee.roaster == Roaster.name`.

struct Roaster: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let city: String
    let country: String
    let flag: String
    let about: String
    let website: String?

    var location: String { "\(city), \(country)" }

    var websiteURL: URL? { website.flatMap(URL.init(string:)) }

    /// Host without the scheme, for display (e.g. "manhattancoffeeroasters.com").
    var websiteLabel: String? {
        websiteURL?.host?.replacingOccurrences(of: "www.", with: "")
    }
}

extension Roaster {
    static let all: [Roaster] = [
        Roaster(
            name: "Manhattan Coffee Roasters",
            city: "Rotterdam", country: "Netherlands", flag: "🇳🇱",
            about: "Founded in 2017, Manhattan Coffee Roasters is one of Rotterdam's most awarded roasters, driven by a passion for exceptional, ethically sourced coffee. The team brings decades of combined experience, working closely with producers to source smarter and roast better — with transparency and sustainability at the core.",
            website: "https://manhattancoffeeroasters.com"
        ),
        Roaster(
            name: "Man Met Bril Koffie",
            city: "Rotterdam", country: "Netherlands", flag: "🇳🇱",
            about: "Philip Reade's celebrated roastery, tucked beneath the old railway viaduct in Rotterdam's Agniesebuurt. One of the most respected specialty roasters in the Netherlands, Man Met Bril's beans appear on café menus across the country.",
            website: "https://www.manmetbrilkoffie.com"
        ),
        Roaster(
            name: "Giraffe Coffee Roasters",
            city: "Rotterdam", country: "Netherlands", flag: "🇳🇱",
            about: "A Rotterdam specialty roastery selecting beans with distinctive character from premier regions across Central & South America, Africa and Indonesia. Sustainability and fair trade sit at the heart of everything, with transparent, traceable sourcing and fair prices for the farmers they work with.",
            website: "https://giraffecoffee.com"
        ),
        Roaster(
            name: "Shokunin Coffee",
            city: "Rotterdam", country: "Netherlands", flag: "🇳🇱",
            about: "A Rotterdam roastery devoted to diverse flavours and honest, transparent sourcing stories. Shokunin builds sustainable direct-trade partnerships with producers and invests in educating farmers, professionals and coffee lovers throughout the supply chain.",
            website: "https://shokunin.coffee"
        ),
        Roaster(
            name: "Schot Coffee Roasters",
            city: "Rotterdam", country: "Netherlands", flag: "🇳🇱",
            about: "A specialty roastery set in Rotterdam's historic 1929 Diepeveen building, built on premium quality, craftsmanship and engagement. Beans are sourced directly from farmers and roasted in small weekly batches on a Giesen W15, served alongside espresso and hand brews at their bar.",
            website: "https://schotcoffeeroasters.nl"
        ),
    ]

    static let registry: [String: Roaster] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

    /// The roaster metadata for a coffee's roaster name, if we have a profile.
    static func named(_ name: String?) -> Roaster? {
        name.flatMap { registry[$0] }
    }
}
