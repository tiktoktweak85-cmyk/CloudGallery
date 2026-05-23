import SwiftUI

@main
struct CloudGalleryApp: App {
    @StateObject private var storageViewModel = StorageViewModel()
    // إنشاء كائن الحالة المركزي لإدارة الصور والألبومات في التطبيق بالكامل
    @StateObject private var galleryViewModel = GalleryViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // الواجهة الأولى: معرض الألبومات الحقيقي المطابق لتطبيق Photos الأصلي لآبل
                NavigationView {
                    AlbumGridView(galleryVM: galleryViewModel)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Albums")
                }
                
                // الواجهة الثانية: الإعدادات وإدارة منصات التخزين السحابي والـ APIs الفعلي
                CloudSettingsView()
                    .environmentObject(storageViewModel)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
            }
            .accentColor(.blue)
        }
    }
}
