import SwiftUI
import Charts

// MARK: - UserProfileView

struct UserProfileView: View {
    @Environment(AuthService.self) private var authService
    @State private var reviews: [CoffeeReview] = []
    @State private var isLoading = false
    private let reviewService = MockReviewService()

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

            AppleSignInButton(style: .black) {
                authService.startAppleSignIn()
            }
            .frame(height: 52)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.creamBackground)
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
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
                    flavorProfileSection
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

    // MARK: - Flavor Profile Chart

    private var flavorProfileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Flavor Profile")
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
