import SwiftUI

/// Profile page for a roaster: its story, where it's based, and every bean it
/// roasts. Reached by tapping the roaster name on a coffee detail screen.
struct RoasterDetailView: View {
    let roaster: Roaster

    @State private var beans: [Coffee] = []
    @State private var isLoading = true
    private let coffeeService = APICoffeeService()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
                aboutSection
                Divider()
                beansSection
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(Color.creamBackground)
        .navigationTitle(roaster.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let all = try? await coffeeService.fetchCoffees() {
                beans = all
                    .filter { $0.roaster == roaster.name }
                    .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            }
            isLoading = false
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.terracotta.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(Color.terracotta)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(roaster.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.espresso)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("\(roaster.flag) \(roaster.location)", systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let url = roaster.websiteURL {
                Link(destination: url) {
                    Label(roaster.websiteLabel ?? "Website", systemImage: "globe")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.terracotta)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About")
            Text(roaster.about)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Beans

    private var beansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Beans")
                if !beans.isEmpty {
                    Text("\(beans.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(Color.espresso)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if beans.isEmpty {
                Text("No beans available right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(beans) { coffee in
                        NavigationLink(value: coffee) {
                            CoffeeCardView(coffee: coffee)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
