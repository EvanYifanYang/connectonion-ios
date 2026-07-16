import SwiftUI
import UIKit

/// The "Add to chat" bottom sheet opened by the composer's + button — Camera, Photo Library, and
/// Files. (No projects / tools / research / web-search rows; ConnectOnion doesn't have those.)
struct AttachmentSheet: View {
    var allowsImages: Bool
    var allowsFiles: Bool
    var onCamera: () -> Void
    var onPhotos: () -> Void
    var onFiles: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            List {
                if allowsImages, cameraAvailable {
                    row("Camera", systemImage: "camera", action: onCamera)
                }
                if allowsImages {
                    row("Photo Library", systemImage: "photo.on.rectangle", action: onPhotos)
                }
                if allowsFiles {
                    row("Add files", systemImage: "doc", action: onFiles)
                }
            }
            .navigationTitle("Add to chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
    }

    private var sheetHeight: CGFloat {
        let rows = (allowsImages && cameraAvailable ? 1 : 0) + (allowsImages ? 1 : 0) + (allowsFiles ? 1 : 0)
        return CGFloat(120 + rows * 56)
    }

    private func row(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.body)
        }
        .tint(.primary)
    }
}
