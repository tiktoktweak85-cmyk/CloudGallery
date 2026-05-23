import SwiftUI

struct AlbumGridView: View {
    @ObservedObject var galleryVM: GalleryViewModel
    @EnvironmentObject var storageManager: StorageViewModel // جلب كائن المساحات
    @State private var showCreateAlbumAlert = false
    @State private var newAlbumName = ""
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    Text("My Albums")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button(action: { showCreateAlbumAlert = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                if galleryVM.albums.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 100)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(Color(.systemGray4))
                        Text("No Albums Yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(galleryVM.albums) { album in
                            // تمرير بيئة الحسابات السحابية لواجهة الصور الداخلية لتمكين الرفع الذكي
                            NavigationLink(destination: MediaGridView(album: album, galleryVM: galleryVM).environmentObject(storageManager)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .bottomTrailing) {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray6))
                                            
                                            // تغيير الأيقونة الافتراضية بناءً على نوع الألبوم لمحاكاة آبل
                                            Image(systemName: album.name == "Favorites" ? "heart.fill" : (album.name == "Recent" ? "clock.fill" : "photo"))
                                                .font(.system(size: 30))
                                                .foregroundColor(album.name == "Favorites" ? .pink : Color(.systemGray3))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            
                                            Image(systemName: album.isFullySynced ? "checkmark.cloud.fill" : "arrow.clockwise.cloud")
                                                .font(.system(size: 14))
                                                .foregroundColor(album.isFullySynced ? .blue : .orange)
                                                .padding(6)
                                                .background(Color(.systemBackground).opacity(0.8))
                                                .clipShape(Circle())
                                                .padding(8)
                                        }
                                        .frame(width: geo.size.width, height: geo.size.width)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(album.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text("\(album.itemCount)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 2)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Gallery")
        .sheet(isPresented: $showCreateAlbumAlert) {
            NavigationView {
                Form {
                    Section(header: Text("New Cloud Album Description")) {
                        TextField("Album Name", text: $newAlbumName)
                    }
                }
                .navigationTitle("New Album")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        newAlbumName = ""
                        showCreateAlbumAlert = false
                    },
                    trailing: Button("Create") {
                        if !newAlbumName.isEmpty {
                            galleryVM.createNewCloudAlbum(named: newAlbumName)
                            newAlbumName = ""
                            showCreateAlbumAlert = false
                        }
                    }
                    .disabled(newAlbumName.isEmpty)
                )
            }
        }
    }
}
