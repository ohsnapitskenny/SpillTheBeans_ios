import Foundation

// MARK: - Protocol

@MainActor
protocol ReviewServiceProtocol: Sendable {
    func fetchReviews(for coffeeId: UUID) async throws -> [CoffeeReview]
    func fetchMyReviews(userId: String) async throws -> [CoffeeReview]
}

// MARK: - Mock Implementation

@MainActor
final class MockReviewService: ReviewServiceProtocol, Sendable {

    // MARK: Data pools

    private let usernames = [
        "barista.james", "coffeelena", "brew.maven", "pour_max",
        "espresso.finn", "morning.roast", "slowbrew.sara", "coffeenerd42",
        "thirdwave.tom", "beanwhisperer"
    ]

    private let reviewNotes = [
        "Absolutely stunning clarity. Best pour over I've had this year.",
        "The floral notes really shine as an espresso. Surprisingly complex.",
        "Made this as a flat white — the sweetness balanced the milk perfectly.",
        "Tried it as cold brew overnight. Very smooth and low acidity.",
        "A bit too light for my taste in a latte, but beautiful as a pour over.",
        "Really brought out the fruity notes with AeroPress. Highly recommend.",
        "Clean, bright, and refreshing. Will definitely order again.",
        "The chocolate undertones are incredible in a French press.",
        "Excellent balance. Works beautifully in every brew method I've tried.",
        "Floral and delicate. A very special cup.",
        "Beautiful for slow mornings — very meditative brew.",
        "Incredible aroma. My go-to morning pour over bean."
    ]

    // MARK: fetchReviews

    func fetchReviews(for coffeeId: UUID) async throws -> [CoffeeReview] {
        // Simulate a short network delay
        try await Task.sleep(for: .milliseconds(180))

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(coffeeId.hashValue)) &+ 1)
        let count = 3 + Int(rng.next() % 5)   // 3–7 reviews

        let calendar = Calendar.current
        let now = Date()
        var reviews: [CoffeeReview] = []

        for _ in 0..<count {
            let daysAgo = Int(rng.next() % 120) + 1
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let brew = BrewMethod.allCases[Int(rng.next() % UInt64(BrewMethod.allCases.count))]
            let username = usernames[Int(rng.next() % UInt64(usernames.count))]
            let note = reviewNotes[Int(rng.next() % UInt64(reviewNotes.count))]
            let rating = Int(rng.next() % 3) + 3  // 3–5 stars

            reviews.append(CoffeeReview(
                id: UUID(),
                coffeeId: coffeeId,
                userId: "u_\(username)",
                username: username,
                brewMethod: brew,
                rating: rating,
                note: note,
                date: date
            ))
        }

        return reviews.sorted { $0.date > $1.date }
    }

    // MARK: fetchMyReviews

    func fetchMyReviews(userId: String) async throws -> [CoffeeReview] {
        try await Task.sleep(for: .milliseconds(100))

        // Hard-coded "my" reviews referencing the first few coffees in the JSON.
        let coffeeIds: [UUID] = [
            UUID(uuidString: "B1C2D3E4-0001-0001-0001-100000000001")!,
            UUID(uuidString: "B1C2D3E4-0002-0002-0002-200000000002")!,
            UUID(uuidString: "B1C2D3E4-0003-0003-0003-300000000003")!,
            UUID(uuidString: "B1C2D3E4-0004-0004-0004-400000000004")!,
            UUID(uuidString: "B1C2D3E4-0001-0001-0001-100000000001")!,
            UUID(uuidString: "B1C2D3E4-0002-0002-0002-200000000002")!,
            UUID(uuidString: "B1C2D3E4-0003-0003-0003-300000000003")!,
            UUID(uuidString: "B1C2D3E4-0004-0004-0004-400000000004")!,
        ]
        let brews: [BrewMethod]   = [.pourOver, .espresso, .pourOver, .chemex,
                                     .flatWhite, .pourOver, .latte, .aeroPress]
        let ratings: [Int]        = [5, 5, 4, 5, 4, 5, 4, 5]
        let notes = [
            "My favourite morning bean. The jasmine aroma is extraordinary.",
            "Incredible as espresso — blueberry sweetness all the way through.",
            "The honey process gives it a wonderful caramel sweetness.",
            "Bright acidity that really shines in the Chemex.",
            "Tried it as a flat white. So clean and balanced.",
            "Second bag already. The natural process is unlike anything else.",
            "Beautiful latte — the sweetness comes through even with milk.",
            "AeroPress brings out a really juicy, concentrated flavour."
        ]

        let calendar = Calendar.current
        let now = Date()

        return coffeeIds.enumerated().map { index, coffeeId in
            let daysAgo = (index + 1) * 10
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return CoffeeReview(
                id: UUID(),
                coffeeId: coffeeId,
                userId: userId,
                username: "me",
                brewMethod: brews[index],
                rating: ratings[index],
                note: notes[index],
                date: date
            )
        }
    }
}

// MARK: - Deterministic RNG (xorshift64)

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid state == 0, which would produce an infinite stream of zeros
        state = seed == 0 ? 6364136223846793005 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
