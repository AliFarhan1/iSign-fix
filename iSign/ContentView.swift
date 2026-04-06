import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isImporting: Bool = false
    @State private var selectedFileName: String = "اسحب IPA أو اضغط للاختيار"
    
    // تعريف الأنواع بشكل آمن لتجنب أخطاء البناء
    let ipaType = UTType(filenameExtension: "ipa") ?? .data
    let dylibType = UTType(filenameExtension: "dylib") ?? .data

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    // الجزء العلوي
                    HStack {
                        VStack(alignment: .leading) {
                            Text("iSign")
                                .font(.system(size: 40, weight: .black, design: .rounded))
                            Text("توقيع التطبيقات بسهولة")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 10)
                    .padding(.horizontal)

                    // صندوق رفع الملفات
                    VStack(spacing: 20) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 70))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.blue)
                        
                        Text(selectedFileName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.45)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color(UIColor.secondarySystemBackground)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [8]))
                    )
                    .padding(.horizontal)
                    .onTapGesture {
                        isImporting = true
                    }

                    Spacer()

                    // أزرار التحكم السفلية
                    Button(action: { isImporting = true }) {
                        Text("اختر ملف IPA")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.blue)
                            .cornerRadius(20)
                            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 10)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [ipaType, dylibType, .zip, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                selectedFileName = urls.first?.lastPathComponent ?? "ملف غير معروف"
            }
        }
    }
}
