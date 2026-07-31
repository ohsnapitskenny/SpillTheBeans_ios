import SwiftUI
import Charts

// MARK: - UserProfileView

struct UserProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var reviews: [CoffeeReview] = []
    /// Flavor tags for every coffee, keyed by id — used to derive the flavor
    /// radar from the coffees the user has reviewed (reviews carry only the id).
    @State private var coffeeTags: [UUID: [String]] = [:]
    @State private var isLoading = false
    @State private var showAuth  = false
    @State private var authMode  = AuthMode.signIn
    private let reviewService = APIReviewService()
    private let coffeeService = APICoffeeService()

    var body: some View {
        NavigationStack {
            // Read currentUser (stored @Observable property) directly so
            // observation tracking is guaranteed to fire on changes.
            if let user = authService.currentUser, !user.isGuest {
                profileView(user: user)
            } else {
                guestView
            }
        }
    }

    // MARK: - Guest View

    private var guestView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.espresso.opacity(0.08))
                    .frame(width: 110, height: 110)
                Image(systemName: "person.circle")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.terracotta.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("Sign in to unlock your profile")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.espresso)
                Text("Track your reviews and discover your\npersonal flavor profile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    authMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundStyle(Color.onEspresso)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.espresso)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    authMode = .signUp
                    showAuth = true
                } label: {
                    Text("Create Account")
                        .font(.subheadline)
                        .foregroundStyle(Color.terracotta)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuth) {
            AuthView(initialMode: authMode)
                .environment(authService)
        }
    }

    // MARK: - Profile View

    private func profileView(user: AppUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                profileHeader(user: user)

                Divider().padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .tint(Color.espresso)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if reviews.isEmpty {
                    emptyReviewsNote
                } else {
                    flavorRadarSection
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    brewMethodSection
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    myReviewsSection
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 40)
        }
        .background(Color.creamBackground)
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out") { authService.signOut() }
                    .font(.subheadline)
                    .foregroundStyle(Color.terracotta)
            }
        }
        .task {
            isLoading = true
            reviews = (try? await reviewService.fetchMyReviews(userId: user.id)) ?? []
            if let coffees = try? await coffeeService.fetchCoffees() {
                coffeeTags = Dictionary(
                    coffees.map { ($0.id, $0.flavorTags) },
                    uniquingKeysWith: { first, _ in first }
                )
            }
            isLoading = false
        }
    }

    // MARK: - Profile Header

    private func profileHeader(user: AppUser) -> some View {
        HStack(spacing: 16) {
            // Avatar circle with initial
            ZStack {
                Circle()
                    .fill(Color.espresso.opacity(0.1))
                    .frame(width: 68, height: 68)
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.espresso)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.espresso)
                if let email = user.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Color.terracotta)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Flavor Radar

    private var flavorRadarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Flavor Profile")
            Text("Based on the beans you've reviewed")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let scores = flavorScores
            if scores.contains(where: { $0.rawCount > 0 }) {
                RadarChartView(scores: scores)
                    .frame(height: 260)
                    .padding(.top, 4)

                if let top = scores.max(by: { $0.rawCount < $1.rawCount }), top.rawCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Your palate leans **\(top.name.lowercased())**")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.terracotta)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Text("Review a few more coffees to reveal your flavor profile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    /// Broad flavor axes for the radar, with the tag keywords that feed each.
    private static let flavorCategories: [(name: String, keywords: [String])] = [
        ("Fruity", ["berry","berries","blueberry","raspberry","strawberry","cherry","currant",
                    "cranberry","apple","pear","peach","apricot","plum","nectarine","mango",
                    "pineapple","tropical","passion","guava","lychee","grape","melon","fig",
                    "raisin","date","banana","goji","cactus","gooseberry","papaya","fruit"]),
        ("Citrus", ["citrus","orange","lemon","lime","grapefruit","bergamot","mandarin",
                    "clementine","tangerine"]),
        ("Floral", ["floral","jasmin","jasmine","rose","lavender","hibiscus","elderflower",
                    "blossom","chamomile","lilac","magnolia","honeysuckle","violet","tea",
                    "earl grey","darjeeling","rooibos","herbal"]),
        ("Sweet", ["sweet","caramel","honey","sugar","toffee","molasses","vanilla","fudge",
                   "nougat","syrup","candied"]),
        ("Chocolate", ["chocolate","cocoa","cacao"]),
        ("Nutty", ["nutty","almond","hazelnut","walnut","pecan","macadamia","cashew",
                   "peanut","marzipan"]),
    ]

    /// Category scores from the reviewed coffees' flavor tags, normalised so the
    /// strongest flavor reaches the outer ring.
    private var flavorScores: [RadarChartView.Score] {
        var counts: [String: Int] = [:]
        for review in reviews {
            guard let tags = coffeeTags[review.coffeeId] else { continue }
            for tag in tags {
                let t = tag.lowercased()
                for cat in Self.flavorCategories
                where cat.keywords.contains(where: { t.contains($0) }) {
                    counts[cat.name, default: 0] += 1
                }
            }
        }
        let maxCount = max(counts.values.max() ?? 0, 1)
        return Self.flavorCategories.map { cat in
            let c = counts[cat.name] ?? 0
            return RadarChartView.Score(name: cat.name,
                                        value: Double(c) / Double(maxCount),
                                        rawCount: c)
        }
    }

    // MARK: - Brew Method Chart

    private var brewMethodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Brew Methods")
            Text("Your brew method breakdown")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let counts = brewMethodCounts

            Chart(counts, id: \.method) { item in
                BarMark(
                    x: .value("Reviews", item.count),
                    y: .value("Method", item.method)
                )
                .foregroundStyle(Color.terracotta.gradient)
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(counts.count) * 38 + 16)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private struct BrewCount {
        let method: String
        let count: Int
    }

    private var brewMethodCounts: [BrewCount] {
        var dict: [String: Int] = [:]
        for review in reviews {
            dict[review.brewMethod.rawValue, default: 0] += 1
        }
        return dict
            .map { BrewCount(method: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - My Reviews

    private var myReviewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "My Reviews")

            VStack(spacing: 10) {
                ForEach(reviews) { review in
                    ReviewRowView(review: review)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyReviewsNote: some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(Color.terracotta.opacity(0.35))
            Text("No reviews yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Your reviews will appear here after you rate a coffee.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding()
    }
}

// ReviewRowView and StarRatingView live in SharedComponents.swift

// MARK: - RadarChartView

/// A basic radar (spider) chart drawn with Canvas. Values are pre-normalised
/// to 0...1, where 1 reaches the outer ring.
struct RadarChartView: View {
    struct Score: Identifiable {
        let id = UUID()
        let name: String
        let value: Double   // 0...1
        let rawCount: Int
    }

    let scores: [Score]

    var body: some View {
        Canvas { context, size in
            let n = scores.count
            guard n >= 3 else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Leave room around the plot for the axis labels.
            let radius = min(size.width, size.height) / 2 - 30

            func point(_ index: Int, _ r: Double) -> CGPoint {
                let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(n)
                return CGPoint(x: center.x + cos(angle) * radius * r,
                               y: center.y + sin(angle) * radius * r)
            }

            func polygon(at r: Double) -> Path {
                var path = Path()
                for i in 0..<n {
                    let p = point(i, r)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
                return path
            }

            // Concentric grid rings
            for ring in stride(from: 0.25, through: 1.0, by: 0.25) {
                context.stroke(polygon(at: ring), with: .color(.gray.opacity(0.18)), lineWidth: 1)
            }

            // Spokes
            for i in 0..<n {
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: point(i, 1.0))
                context.stroke(spoke, with: .color(.gray.opacity(0.15)), lineWidth: 1)
            }

            // Data polygon
            var data = Path()
            for i in 0..<n {
                let p = point(i, max(0.04, scores[i].value))
                if i == 0 { data.move(to: p) } else { data.addLine(to: p) }
            }
            data.closeSubpath()
            context.fill(data, with: .color(Color.terracotta.opacity(0.25)))
            context.stroke(data, with: .color(Color.terracotta), lineWidth: 2)

            // Vertex dots
            for i in 0..<n {
                let p = point(i, max(0.04, scores[i].value))
                let dot = Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(Color.terracotta))
            }

            // Axis labels
            for i in 0..<n {
                let p = point(i, 1.16)
                let label = context.resolve(
                    Text(scores[i].name)
                        .font(.caption2)
                        .foregroundStyle(Color.espresso)
                )
                let anchor: UnitPoint =
                    abs(p.x - center.x) < 4 ? .center : (p.x < center.x ? .trailing : .leading)
                context.draw(label, at: p, anchor: anchor)
            }
        }
        .accessibilityLabel("Flavor profile radar chart")
    }
}
