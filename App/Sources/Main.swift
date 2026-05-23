import SwiftUI

@main
struct CloudGalleryApp: App {
    // كائن الحالة المركزي والمشترك لإدارة الحسابات السحابية والمساحة الحقيقية عبر التطبيق
    @StateObject private var storageViewModel = StorageViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // الواجهة الأولى: المعرض والألبومات (سنقوم بإنشاء ملفها المستقل لاحقاً)
                NavigationView {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        Text("Gallery Interface Container")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .navigationTitle("Gallery")
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Gallery")
                }
                
                // الواجهة الثانية: الإعدادات وإدارة منصات التخزين السحابي الفعلي
                CloudSettingsView()
                    .environmentObject(storageViewModel)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
            }
            .accentColor(.blue) // اللون الرئيسي للتفاعل في التطبيق
        }
    }
}
