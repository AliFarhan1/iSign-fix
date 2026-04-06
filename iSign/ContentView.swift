import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isImporting: Bool = false
    @State private var selectedFileName: String = "اسحب IPA أو اضغط للاختيار"

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // الهيدر - يحترم منطقة النوتش
                HStack {
                    Text("iSign")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
                .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                .padding(.horizontal)

                // منطقة اختيار الملفات - مرنة بالكامل
                VStack(spacing: 15) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(selectedFileName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("يدعم ملفات .ipa و .zip و .dylib")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.4) // يأخذ 40% من طول الشاشة مهما كان نوع الآيفون
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [10]))
                )
                .padding(.horizontal)
                .onTapGesture {
                    isImporting = true
                }

                Spacer()

                // أزرار التحكم السفلية - تحترم منطقة السحب السفلي
                VStack(spacing: 12) {
                    Button(action: { isImporting = true }) {
                        Label("اختيار ملف", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    HStack(spacing: 15) {
                        BottomBarItem(icon: "doc.text.fill", title: "الملفات")
                        BottomBarItem(icon: "pencil.tip.crop.circle", title: "التوقيع")
                        BottomBarItem(icon: "checkmark.seal.fill", title: "الشهادات")
                        BottomBarItem(icon: "cpu", title: "المكتبات")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 20)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [
                UTType(filenameExtension: "ipa")!,
                UTType(filenameExtension: "dylib")!,
                .zip,
                .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileName = url.lastPathComponent
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
    }
}

struct BottomBarItem: View {
    let icon: String
    let title: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
            Text(title).font(.system(size: 10))
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(.secondary)
    }
}
