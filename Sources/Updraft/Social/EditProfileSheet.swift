import SwiftUI
import PhotosUI
import _PhotosUI_SwiftUI

/// Edit your profile: photo, name, @handle and bio in a labeled form.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = SocialStore.shared.me.name
    @State private var handleText = SocialStore.shared.me.handle
    @State private var bio = SocialStore.shared.me.bio
    @State private var photo = SocialStore.shared.photo
    @State private var pickedItem: PhotosPickerItem?
    @FocusState private var focus: Field?

    private enum Field { case name, handle, bio }
    private static let bioLimit = 80

    private var handle: String { SocialStore.normalized(handleText) }
    private var handleValid: Bool { SocialStore.isValidHandle(handle) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { handleValid && !trimmedName.isEmpty }

    var body: some View {
        let pickerTitle = photo == nil ? "Add photo" : "Change photo" // PhotosPicker labels are nonisolated
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: Space.sm) {
                        SocialAvatar(photo: photo, size: 96)
                            .id(photo?.count ?? 0)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        HStack(spacing: Space.md) {
                            PhotosPicker(selection: $pickedItem, matching: .images) {
                                Text(pickerTitle)
                            }
                            if photo != nil {
                                Button("Remove", role: .destructive) {
                                    Haptics.tap()
                                    withAnimation(.snappy) { photo = nil }
                                }
                            }
                        }
                        .font(Typo.callout.weight(.medium))
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(duration: 0.35, bounce: 0.2), value: photo)
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Name") {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .focused($focus, equals: .name)
                            .onSubmit { focus = .handle }
                    }
                    LabeledContent("Handle") {
                        HStack(spacing: 1) {
                            Text("@").foregroundStyle(Theme.textTertiary)
                            TextField("handle", text: $handleText)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.next)
                                .focused($focus, equals: .handle)
                                .onSubmit { focus = .bio }
                        }
                    }
                } footer: {
                    Text(handleNote)
                        .foregroundStyle(handleValid || handle.isEmpty ? Theme.textSecondary : Theme.negative)
                        .contentTransition(.interpolate)
                        .animation(.smooth(duration: 0.2), value: handleNote)
                }

                Section {
                    TextField("A line about you", text: $bio, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focus, equals: .bio)
                        .onChange(of: bio) { _, new in
                            if new.count > Self.bioLimit { bio = String(new.prefix(Self.bioLimit)) }
                        }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("\(bio.count)/\(Self.bioLimit)").monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(Typo.body)
            .tint(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
            .onChange(of: pickedItem) { _, item in loadPhoto(item) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasChanges)
    }

    private var hasChanges: Bool {
        let me = SocialStore.shared.me
        return name != me.name || handle != me.handle || bio != me.bio || photo != SocialStore.shared.photo
    }

    private var handleNote: String {
        if handle.isEmpty { return "3–15 letters, numbers or _." }
        return handleValid ? "updraft.app/u/\(handle)" : "Use 3–15 letters, numbers or _."
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { Haptics.error(); return }
            let scale = 400 / min(image.size.width, image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            withAnimation(.snappy) { photo = resized.jpegData(compressionQuality: 0.8) }
            pickedItem = nil
            Haptics.select()
        }
    }

    private func save() {
        var me = SocialStore.shared.me
        me.name = trimmedName
        me.handle = handle
        me.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        SocialStore.shared.me = me
        SocialStore.shared.photo = photo
        Haptics.success()
        dismiss()
    }
}
