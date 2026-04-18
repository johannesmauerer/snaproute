import SwiftUI
import LinkPresentation
import UIKit

struct ShareSheetView: View {
    let url: URL
    var onOpenInApp: (() -> Void)?
    var onSafari: (() -> Void)?
    var onShelfRead: (() -> Void)?
    var onObsidian: (() -> Void)?
    let onCopyLink: () -> Void
    let onCancel: () -> Void

    @State private var title: String?
    @State private var imageData: Data?
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Grab handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 16)

                    // Link preview
                    HStack(spacing: 14) {
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "globe")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(.secondary)
                                )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title ?? url.host ?? "Loading...")
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            Text(url.host ?? url.absoluteString)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Actions
                    VStack(spacing: 0) {
                        if let onOpenInApp {
                            ShareActionRow(title: "Open in Emberleap", icon: "arrow.up.forward.app", action: onOpenInApp)
                            Divider().padding(.leading, 56)
                        }
                        if let onSafari {
                            ShareActionRow(title: "Open in Safari", icon: "safari", action: onSafari)
                            Divider().padding(.leading, 56)
                        }
                        if let onShelfRead {
                            ShareActionRow(title: "Read Later", icon: "book.closed", action: onShelfRead)
                            Divider().padding(.leading, 56)
                        }
                        if let onObsidian {
                            ShareActionRow(title: "Save Note", icon: "square.and.arrow.down", action: onObsidian)
                            Divider().padding(.leading, 56)
                        }
                        ShareActionRow(title: "Copy Link", icon: "doc.on.doc", action: onCopyLink)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    // Done
                    Button(action: onCancel) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.label))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                .offset(y: appeared ? 0 : 400)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: appeared)
        .onAppear {
            appeared = true
            fetchMetadata()
        }
    }

    private func fetchMetadata() {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, _ in
            DispatchQueue.main.async {
                if let metadata {
                    self.title = metadata.title
                    let imageProvider = metadata.iconProvider ?? metadata.imageProvider
                    imageProvider?.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.imageData = image.pngData()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShareActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 28)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }
}
