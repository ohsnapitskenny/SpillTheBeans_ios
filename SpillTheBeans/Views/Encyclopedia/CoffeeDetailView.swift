import SwiftUI

struct CoffeeDetailView: View {
    let coffee: Coffee

    @State private var reviews: [CoffeeReview] = []
    @State private var reviewsLoading = true
    private let reviewService = MockReviewService()

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
                Spacer()
                if !reviews.isEmpty {
                    Text("\(reviews.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            if reviewsLoading {
                ProgressView()
                    .tint(Color.espresso)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if reviews.isEmpty {
                Text("No reviews yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
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
