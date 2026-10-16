import SwiftUI
import PhotosUI
import _PhotosUI_SwiftUI

/// Edit your profile with a live preview: photo or emoji, color, name, @handle, bio.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SocialStore.shared.me
    @State private var photo = SocialStore.shared.photo
    @State private var pickedItem: PhotosPickerItem?
    @State private var handleText = SocialStore.shared.me.handle
    @State private var fittedHeight: CGFloat = 640
    @State private var detent: PresentationDetent = .height(640)

    private static let emojis = ["🦊", "🐳", "🌙", "🔥", "⚡️", "🌱", "🚀", "💎", "🎯", "🌊", "🍀", "🦄"]
    private static let bioLimit = 80

    private var handle: String { SocialStore.normalized(handleText) }
    private var handleValid: Bool { SocialStore.isValidHandle(handle) }
    private var nameValid: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    preview
                    avatarPicker
                    fields
                }
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.md)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                (geo.contentSize.height + geo.contentInsets.top + geo.contentInsets.bottom).rounded()
            } action: { _, h in
                guard h > 0, abs(h - fittedHeight) > 1 else { return }
                let follow = detent == .height(fittedHeight)
                fittedHeight = h
                if follow { withAnimation(.smooth(duration: 0.3)) { detent = .height(h) } }
            }
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!handleValid || !nameValid)
                }
            }
            .onChange(of: pickedItem) { _, item in loadPhoto(item) }
            .sensoryFeedback(.selection, trigger: draft.emoji)
            .sensoryFeedback(.selection, trigger: draft.color)
        }
        .presentationDetents([.height(fittedHeight), .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    // MARK: Preview

    private var preview: some View {
        VStack(spacing: Space.xs) {
            SocialAvatar(profile: draft, size: 88, photo: photo)
                .overlay(Circle().strokeBorder(Theme.hairline))
                .id("\(photo?.count ?? 0)-\(draft.emoji ?? "")-\(draft.color ?? "")")
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            Text(draft.name.isEmpty ? "Your name" : draft.name)
                .font(Typo.headline)
                .foregroundStyle(draft.name.isEmpty ? Theme.textTertiary : Theme.textPrimary)
            Text("@" + (handle.isEmpty ? "handle" : handle))
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            if !draft.bio.isEmpty {
                Text(draft.bio).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xs)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: draft)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: photo)
    }

    // MARK: Avatar

    private var avatarPicker: some View {
        let hasPhoto = photo != nil
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                ForEach(AccountPalette.keys, id: \.self) { key in
                    let selected = (draft.color ?? "mono") == key
                    Button {
                        draft.color = key == "mono" ? nil : key
                    } label: {
                        Circle()
                            .fill(AccountPalette.color(key) ?? Theme.textPrimary)
                            .frame(width: 26, height: 26)
                            .padding(3)
                            .overlay(Circle().strokeBorder(selected ? Theme.textPrimary : .clear, lineWidth: 1.5))
                            .scaleEffect(selected ? 1.05 : 1)
                            .animation(.spring(duration: 0.3, bounce: 0.4), value: selected)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(key)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: Space.xs) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    PhotoCell(selected: hasPhoto)
                }
                .accessibilityLabel("Choose photo")
                Button { photo = nil; draft.emoji = nil } label: {
                    cell(selected: photo == nil && draft.emoji == nil) {
                        Text(String(draft.name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Initial")
                ForEach(Self.emojis, id: \.self) { e in
                    Button { photo = nil; draft.emoji = e } label: {
                        cell(selected: photo == nil && draft.emoji == e) { Text(e).font(.system(size: 20)) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Space.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
    }

    private func cell<C: View>(selected: Bool, @ViewBuilder content: () -> C) -> some View {
        content()
            .frame(width: 38, height: 38)
            .background(selected ? Theme.surfaceHi : .clear, in: .circle)
            .overlay(Circle().strokeBorder(selected ? Theme.textPrimary : Theme.hairline, lineWidth: selected ? 1.5 : 1))
            .animation(.snappy(duration: 0.2), value: selected)
    }

    // MARK: Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            field("Name") {
                TextField("Your name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            field("Handle", note: handleNote, noteTone: handleValid || handle.isEmpty ? Theme.textSecondary : Theme.negative) {
                HStack(spacing: 2) {
                    Text("@").foregroundStyle(Theme.textTertiary)
                    TextField("handle", text: $handleText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                }
            }
            field("Bio", note: "\(draft.bio.count)/\(Self.bioLimit)", noteTone: Theme.textTertiary) {
                TextField("A line about you", text: $draft.bio, axis: .vertical)
                    .lineLimit(1...3)
                    .onChange(of: draft.bio) { _, new in
                        if new.count > Self.bioLimit { draft.bio = String(new.prefix(Self.bioLimit)) }
                    }
            }
        }
    }

    private var handleNote: String {
        if handle.isEmpty { return "3–15 letters, numbers or _." }
        return handleValid ? "updraft.app/u/\(handle)" : "Use 3–15 letters, numbers or _."
    }

    private func field<C: View>(_ title: String, note: String? = nil, noteTone: Color = Theme.textSecondary,
                                @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(Typo.callout).foregroundStyle(Theme.textSecondary)
            content()
                .font(Typo.body)
                .foregroundStyle(Theme.textPrimary)
                .padding(Space.md)
                .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
            if let note {
                Text(note).font(Typo.caption).foregroundStyle(noteTone)
                    .contentTransition(.interpolate)
                    .animation(.smooth(duration: 0.2), value: note)
            }
        }
    }

    // MARK: Actions

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { Haptics.error(); return }
            // Square-ish thumbnail keeps storage small.
            let side: CGFloat = 400
            let scale = side / min(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            photo = resized.jpegData(compressionQuality: 0.8)
            draft.emoji = nil
            Haptics.select()
        }
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.handle = handle
        draft.bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        SocialStore.shared.me = draft
        SocialStore.shared.photo = photo
        Haptics.success()
        dismiss()
    }
}

/// Photo option in the avatar grid (its own view: PhotosPicker labels are nonisolated).
private struct PhotoCell: View {
    let selected: Bool
    var body: some View {
        Image(systemName: "photo")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: 38, height: 38)
            .background(selected ? Theme.surfaceHi : .clear, in: .circle)
            .overlay(Circle().strokeBorder(selected ? Theme.textPrimary : Theme.hairline, lineWidth: selected ? 1.5 : 1))
    }
}
