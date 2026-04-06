import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isImporting: Bool = false
    @State private var selectedFileName: String = "اسحب IPA أو اضغط للاختيار"

    // تعريف أنواع الملفات المدعومة بشكل آمن
    let supportedTypes: [UTType] = [
        UTType.data, 
        UTType.zip,
        UTType(filenameExtension: "ipa") ?? .data,
        UTType(filenameExtension: "dylib") ?? .data
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // الرأس (Header)
                HStack {
                    Text("iSign")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
                .padding(.top, geometry.safeAreaInsets.top > 20 ? geometry.safeAreaInsets.top : 30)
                .padding(.horizontal)

                // منطقة اختيار الملف (Box)
                VStack(spacing: 15) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(selectedFileName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.4)
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

                // زر الاختيار السفلي
                Button(action: { isImporting = true }) {
                    Label("اختيار ملف", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 20)
            }
        }
        .edgesIgnoringSafeArea(.all)
        // هذا الجزء هو الذي تسبب في الخطأ وتم إصلاحه هنا
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            do {
                let selectedFiles = try result.get()
                if let url = selectedFiles.first {
                    selectedFileName = url.lastPathComponent
                    // هنا يمكنك إضافة منطق معالجة الملف بعد اختياره
                }
            } catch {
                print("فشل اختيار الملف: \(error.localizedDescription)")
            }
        }
    }
}
