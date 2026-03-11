import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                Color.black
                    .overlay {
                        Text("Photo preview unavailable")
                            .foregroundColor(.white)
                    }
            }
        }
    }
}
