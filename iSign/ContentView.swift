import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isPickerPresented = false
    @State private var fileName = "لم يتم اختيار ملف"
    
    // تعريف النوع لتجنب أخطاء البناء
    let ipaType = UTType(filenameExtension: "ipa") ?? .data

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 5) {
                        Text("iSign")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                        Text("إصدار الإصلاح النهائي")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 20)
                    .padding(.bottom, 20)

                    // Upload Area
                    Button(action: { isPickerPresented = true }) {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 70))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.blue)
                            
                            VStack(spacing: 8) {
                                Text(fileName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("اضغط هنا لاختيار ملف IPA أو Dylib")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geo.size.height * 0.45)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    }
                    .padding(.horizontal, 25)

                    Spacer()

                    // Bottom Button
                    Button(action: { isPickerPresented = true }) {
                        Text("بدء التوقيع")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.blue)
                            .cornerRadius(18)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 10)
                }
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [ipaType, .data, .zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                fileName = urls.first?.lastPathComponent ?? "ملف غير معروف"
            }
        }
    }
}
