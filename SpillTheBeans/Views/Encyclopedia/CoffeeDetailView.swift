import SwiftUI

struct CoffeeDetailView: View {
    let coffee: Coffee

    @Environment(AuthService.self) private var authService

    @State private var reviews: [CoffeeReview] = []
    @State private var reviewsLoading = true
    @State private var showingAddReview = false
    @State private var showingSignInPrompt = false
    private let reviewService = APIReviewService()

    /// Only signed-in (non-guest) users can post a review.
    private var canReview: Bool {
        guard let user = authService.currentUser else { return false }
        return !user.isGuest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                heroSection
                Divider()
                originSection
                processSection
                roastSection
                flavorSection
                tastingNoteSection
                if coffee.producer != nil || coffee.altitude != nil || coffee.harvestSeason != nil {
                    producerSection
                }
                Divider()
                reviewsSection
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(Color.creamBackground)
        .navigationTitle(coffee.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            reviews = (try? await reviewService.fetchReviews(for: coffee.id)) ?? []
            reviewsLoading = false
        }
        .sheet(isPresented: $showingAddReview) {
            AddReviewView(coffee: coffee) { newReview in
                // Show the new review immediately at the top of the list.
                reviews.insert(newReview, at: 0)
            }
        }
        .alert("Sign in to review", isPresented: $showingSignInPrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create an account or sign in from the Me tab to write a review.")
        }
    }

    private func addReviewTapped() {
        if canReview {
            showingAddReview = true
        } else {
            showingSignInPrompt = true
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(coffee.origin.flag).font(.system(size: 64))
                Text(coffee.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.espresso)
                Text([coffee.origin.country, coffee.origin.region]
                    .compactMap { $0 }
                    .joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let roaster = coffee.roaster {
                    if let info = Roaster.named(roaster) {
                        NavigationLink(value: info) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame")
                                Text(roaster)
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.terracotta)
                        }
                    } else {
                        Label(roaster, systemImage: "flame")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.terracotta)
                    }
                }
            }
            Spacer()
            ProcessBadge(process: coffee.process)
        }
    }

    // MARK: - Origin

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Origin")
            HStack(spacing: 10) {
                InfoTile(label: "Country", value: coffee.origin.country)
                if let region = coffee.origin.region {
                    InfoTile(label: "Region", value: region)
                }
            }
        }
    }

    // MARK: - Process

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Processing Method")
            VStack(alignment: .leading, spacing: 10) {
                ProcessBadge(process: coffee.process)
                Text(coffee.process.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Roast

    private var roastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Roast Level")
            VStack(alignment: .leading, spacing: 6) {
                Text(coffee.roastLevel.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.espresso)
                RoastLevelBar(level: coffee.roastLevel).frame(height: 10)
            }
        }
    }

    // MARK: - Flavor

    private var flavorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Flavor Profile")
            FlowLayout(spacing: 8) {
                ForEach(coffee.flavorTags, id: \.self) { tag in
                    FlavorTagView(tag: tag, style: .large)
                }
            }
        }
    }

    // MARK: - Tasting Note

    private var tastingNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tasting Notes")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundStyle(Color.terracotta.opacity(0.4))
                Text(coffee.tastingNote)
                    .font(.body)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.espresso.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Producer

    private var producerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Producer Details")
            HStack(spacing: 10) {
                if let producer = coffee.producer {
                    InfoTile(label: "Producer", value: producer)
                }
                if let altitude = coffee.altitude {
                    InfoTile(label: "Altitude", value: altitude)
                }
                if let season = coffee.harvestSeason {
                    InfoTile(label: "Harvest", value: season)
                }
            }
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Reviews")
                if !reviews.isEmpty {
                    Text("\(reviews.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: addReviewTapped) {
                    Label("Add Review", systemImage: "square.and.pencil")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .tint(Color.terracotta)
            }

            if reviewsLoading {
                ProgressView()
                    .tint(Color.espresso)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if reviews.isEmpty {
                Button(action: addReviewTapped) {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                        Text("Be the first to review this coffee")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(reviews) { review in
                        ReviewRowView(review: review)
                    }
                }
            }
        }
    }
}

// MARK: - Add Review composer

struct AddReviewView: View {
    let coffee: Coffee
    /// Called with the newly created review after a successful post.
    var onSubmitted: (CoffeeReview) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rating = 0
    @State private var brewMethod: BrewMethod = .pourOver
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let reviewService = APIReviewService()

    private var isValid: Bool {
        rating > 0 && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Rating") {
                    StarRatingPicker(rating: $rating)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }

                Section("Brew Method") {
                    Picker("Brew Method", selection: $brewMethod) {
                        ForEach(BrewMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.systemImage).tag(method)
                        }
                    }
                }

                Section("Your Review") {
                    TextField("How did it taste?", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Review \(coffee.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.espresso)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await submit() } }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.espresso)
                            .disabled(!isValid)
                    }
                }
            }
            .tint(Color.espresso)
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let review = try await reviewService.createReview(
                coffeeId: coffee.id,
                brewMethod: brewMethod,
                rating: rating,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSubmitted(review)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - Star rating picker

private struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title)
                    .foregroundStyle(star <= rating ? Color.terracotta : Color.secondary.opacity(0.4))
                    .onTapGesture { rating = star }
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
    }
}
