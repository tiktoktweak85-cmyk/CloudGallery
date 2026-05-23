import SwiftUI

struct MediaGridView: View {
    let album: CloudAlbum
    @ObservedObject var galleryVM: GalleryViewModel
    
    // شبكة من 3 أعمدة متراصة تماماً لعرض الصور الفردية داخل الألبوم
    private let mediaColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            if album.assets.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 150)
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Photos or Videos")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Media assets uploaded to this node folder will appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: mediaColumns, spacing: 2) {
                    ForEach(album.assets) { asset in
                        GeometryReader { geo in
                            ZStack(alignment: .bottomTrailing) {
                                // مربع الصورة الافتراضي لحين الرفع/التحميل الحقيقي
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                
                                // إذا كان الملف فيديو، نضع أيقونة ومدة الفيديو أسفل اليمين مثل آبل
                                if asset.mediaType == .video {
                                    HStack(spacing: 3) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 9))
                                        Text("0:05") // كمثال للمؤشر
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(4)
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.width)
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                    }
                }
                .padding(.top, 4)
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
