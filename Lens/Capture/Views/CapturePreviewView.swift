import SwiftUI

struct CapturePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: CapturePreviewViewModel
    @State private var showSavedToast = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            previewContent
            
            VStack(spacing: 0) {
                topBar
                Spacer()
                // quickShareBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
            
            if showSavedToast {
                savedToast
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.saveState) { _, newState in
            if newState == .saved {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showSavedToast = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSavedToast = false
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingShareSheet) {
            ActivityView(activityItems: viewModel.shareItems)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
    
    @ViewBuilder
    private var previewContent: some View {
        switch viewModel.media.type {
        case .photo:
            PhotoPreviewView(
                image: viewModel.media.previewImage
                    ?? UIImage(contentsOfFile: viewModel.media.fileURL.path)
            )
        case .video:
            VideoPreviewPlayerView(url: viewModel.media.fileURL)
                .ignoresSafeArea()
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.closeAndDeleteTemporaryMedia()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassPanel(cornerRadius: 18, padding: 0)
            
            Spacer()
            
            smallActionButton(
                title: saveButtonTitle,
                systemImage: "arrow.down.to.line"
            ) {
                viewModel.saveToGallery()
            }
            
            smallActionButton(
                title: "Share",
                systemImage: "square.and.arrow.up"
            ) {
                viewModel.share()
            }
        }
    }
    
    private func smallActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 18, padding: 0)
    }
    
    private var quickShareBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                shareButton(title: "Instagram", systemImage: "camera") {
                    viewModel.share()
                }
                
                shareButton(title: "TikTok", systemImage: "music.note") {
                    viewModel.share()
                }
                
                shareButton(title: "Telegram", systemImage: "paperplane") {
                    viewModel.share()
                }
                
                shareButton(title: "YouTube", systemImage: "play.rectangle") {
                    viewModel.share()
                }
                
                shareButton(title: "More", systemImage: "ellipsis") {
                    viewModel.share()
                }
            }
            .padding(.top, 12)
        }
    }
    
    private func shareButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 68, height: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 18, padding: 0)
    }
    
    private var saveButtonTitle: String {
        switch viewModel.saveState {
        case .idle:
            return "Save"
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed:
            return "Retry Save"
        }
    }
    
    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)
            
            Text("Saved!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .glassPanel(cornerRadius: 20, padding: 14)
        .allowsHitTesting(false)
    }
}

#Preview("Photo") {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-photo.jpg")
    
    let image = UIImage(systemName: "photo")!
    let data = image.jpegData(compressionQuality: 1.0) ?? Data()
    try? data.write(to: tempURL)
    
    let media = CapturedMedia(
        type: .photo,
        fileURL: tempURL,
        previewImageData: data
    )
    
    return CapturePreviewView(
        viewModel: CapturePreviewViewModel(media: media)
    )
}

#Preview("Video") {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-video.mp4")
    
    let media = CapturedMedia(
        type: .video,
        fileURL: tempURL,
        previewImageData: nil
    )
    
    return CapturePreviewView(
        viewModel: CapturePreviewViewModel(media: media)
    )
}
