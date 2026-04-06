import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isPickerPresented = false
    @State private var fileName = "لم يتم اختيار ملف"

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // الجزء العلوي (Header)
                VStack {
                    Text("iSign")
                        .font(.system(size: 45, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text("إصدار الإصلاح الشامل 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, geo.safeAreaInsets.top + 20)
                .padding(.bottom, 30)

                // منطقة الرفع (Upload Zone)
                Button(action: { isPickerPresented = true }) {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                        
                        VStack(spacing: 8) {
                            Text(fileName)
                                .font(.headline)
                                .lineLimit(1)
                            Text("اضغط هنا لاختيار ملف IPA أو Dylib")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.45)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(35)
                    .overlay(
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [10]))
                    )
                }
                .padding(.horizontal, 25)

                Spacer()

                // زر التوقيع السفلي
                Button(action: { isPickerPresented = true }) {
                    HStack {
                        Image(systemName: "pencil.tip.crop.circle.badge.plus")
                        Text("بدء عملية التوقيع")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(22)
                    .shadow(radius: 10, y: 5)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, geo.safeAreaInsets.bottom + 15)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.data, .zip, UTType(filenameExtension: "ipa") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                fileName = urls.first?.lastPathComponent ?? "ملف غير معروف"
            }
        }
    }
}
