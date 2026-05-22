import SwiftUI

@main
struct CloudGalleryApp: App {
    var body: some Scene {
        WindowGroup {
            MainGalleryView()
        }
    }
}

struct MainGalleryView: View {
    // إعداد 3 أعمدة لشبكة الصور (مثل تطبيق الصور في الآيفون)
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                // شبكة وهمية مؤقتة لنرى شكل المعرض قبل ربطه بالسحابة
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<15, id: \.self) { index in
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(10)
                            .overlay(
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundColor(.gray.opacity(0.8))
                                    .font(.system(size: 24))
                            )
                    }
                }
                .padding()
            }
            .navigationTitle("معرضي السحابي")
            // زر علوي سنستخدمه لاحقاً لربط حسابك السحابي أو رفع الصور
            .navigationBarItems(trailing: Button(action: {
                print("زر السحابة يعمل!")
            }) {
                Image(systemName: "cloud.fill")
                    .font(.title3)
            })
        }
    }
}
