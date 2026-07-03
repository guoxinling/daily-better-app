import SwiftUI

struct CompactTabBar: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var selection: AppDestination

  var body: some View {
    HStack(spacing: 8) {
      tabButton(
        destination: .checkIn,
        title: "Check In",
        systemImage: "plus.circle",
        accessibilityIdentifier: "tab.checkIn"
      )
      tabButton(
        destination: .timeline,
        title: "Timeline",
        systemImage: "clock",
        accessibilityIdentifier: "tab.timeline"
      )
    }
    .padding(4)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(DailyBetterStyle.hairline, lineWidth: 1)
    }
    .frame(maxWidth: 520)
    .padding(.horizontal, 24)
  }

  private func tabButton(
    destination: AppDestination,
    title: String,
    systemImage: String,
    accessibilityIdentifier: String
  ) -> some View {
    Button {
      selection = destination
    } label: {
      tabLabel(title: title, systemImage: systemImage)
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 68 : 48)
        .foregroundStyle(selection == destination ? Color.white : DailyBetterStyle.muted)
        .background(
          selection == destination ? DailyBetterStyle.tint : Color.clear,
          in: RoundedRectangle(cornerRadius: 15)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(selection == destination ? .isSelected : [])
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  @ViewBuilder
  private func tabLabel(title: String, systemImage: String) -> some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(spacing: 2) {
        Image(systemName: systemImage)
        Text(title)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 4)
    } else {
      Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
  }
}
