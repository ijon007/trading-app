import SwiftUI

extension View {
    /// Small leading title at the very top instead of the tall native large title.
    /// Shared by Explore and Social so both tabs start at the same height.
    func compactHeader(_ title: String) -> some View {
        self
            .toolbarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(Typo.titleTracking)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .fixedSize() // toolbar items get a narrow proposal; take the full title width
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}
