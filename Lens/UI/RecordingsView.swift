import SwiftUI

struct RecordingsView: View {

  @EnvironmentObject private var store: AppMediaStore

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(store.captures) { item in
          CaptureCell(item: item) {
            share(item)
          }
        }
      }
      .padding(16)
    }
    .background(DesignSystem.Colors.background)
  }

  private func share(_ item: CaptureItem) {
  }
}

private struct CaptureCell: View {
  let item: CaptureItem
  let onShare: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(DesignSystem.Colors.lightGray.opacity(0.25))
          .frame(height: 120)
          .overlay(
            VStack(spacing: 6) {
              Image(systemName: item.kind == .photo ? "photo" : "video")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.8))

              Text(item.kind == .photo ? "Фото" : "Видео")
                .font(DesignSystem.Fonts.medium12)
                .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.7))
            }
          )

        Button(action: onShare) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
        }
        .padding(10)
      }

      Text(dateText(item.createdAt))
        .font(DesignSystem.Fonts.regular12)
        .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.65))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
  }

  private func dateText(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: date)
  }
}
