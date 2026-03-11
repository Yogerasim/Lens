import SwiftUI

struct CapturePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: CapturePreviewViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            previewContent
            
            VStack {
                topBar
                Spacer()
                quickShareBar
            }
            .padding()
        }
        .onAppear {
            viewModel.onAppear()
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
            PhotoPreviewView(image: viewModel.media.previewImage ?? UIImage(contentsOfFile: viewModel.media.fileURL.path))
        case .video:
            VideoPreviewPlayerView(url: viewModel.media.fileURL)
        }
    }
    
    private var topBar: some View {
        HStack {
            Button {
                viewModel.closeAndDeleteTemporaryMedia()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button {
                viewModel.saveToGallery()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line")
                    Text(saveButtonTitle)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            
            Button {
                viewModel.share()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
    
    private var quickShareBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ShareDestinationButton(title: "Instagram", systemImage: "camera") {
                    viewModel.share()
                }
                ShareDestinationButton(title: "TikTok", systemImage: "music.note") {
                    viewModel.share()
                }
                ShareDestinationButton(title: "Telegram", systemImage: "paperplane") {
                    viewModel.share()
                }
                ShareDestinationButton(title: "YouTube", systemImage: "play.rectangle") {
                    viewModel.share()
                }
                ShareDestinationButton(title: "More", systemImage: "ellipsis") {
                    viewModel.share()
                }
            }
        }
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
}
