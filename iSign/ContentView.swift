import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            IPABrowserView()
                .tabItem {
                    Label("الملفات", systemImage: "folder.fill")
                }
            SigningView()
                .tabItem {
                    Label("التوقيع", systemImage: "signature")
                }
            CertificatesView()
                .tabItem {
                    Label("الشهادات", systemImage: "checkmark.seal.fill")
                }
            DylibManagerView()
                .tabItem {
                    Label("المكتبات", systemImage: "cpu.fill")
                }
            SettingsView()
                .tabItem {
                    Label("الإعدادات", systemImage: "gear")
                }
        }
        .accentColor(.blue)
    }
}
