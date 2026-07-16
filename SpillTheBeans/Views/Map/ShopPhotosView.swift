import SwiftUI

/// Paged photo carousel for a shop, fed by Google Places photos.
struct ShopPhotosView: View {
    let photos: [URL]

    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TabView(selection: $page) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder(systemImage: "photo")
                        default:
                            placeholder(systemImage: nil)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Photos from Google")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Rectangle().fill(Color.cream.opacity(0.5))
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView().tint(Color.espresso)
            }
        }
    }
}
