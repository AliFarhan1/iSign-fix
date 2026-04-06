import Foundation
import ZIPFoundation
import UIKit

struct IPAInfo {
    var bundleID: String
    var displayName: String
    var version: String
    var buildNumber: String
    var minOSVersion: String
    var executableName: String
    var teamID: String?
    var entitlements: [String: Any]
    var embeddedDylibs: [String]
    var iconData: Data?
    var plistData: [String: Any]
}

struct DylibInfo: Identifiable {
    var id = UUID()
    var name: String
    var path: String
    var size: Int64
    var isInjected: Bool
    var archs: [String]
}

class iSignEngine: ObservableObject {
    static let shared = iSignEngine()

    @Published var currentIPAPath: URL?
    @Published var ipaInfo: IPAInfo?
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var extractedPath: URL?

    private let fileManager = FileManager.default
    let workDir: URL

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        workDir = docs.appendingPathComponent("iSign_Work")
        try? fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    func extractIPA(at url: URL) async throws -> URL {
        let dest = workDir.appendingPathComponent(
            url.deletingPathExtension().lastPathComponent)
        try? fileManager.removeItem(at: dest)
        try fileManager.createDirectory(at: dest, withIntermediateDirectories: true)
        await MainActor.run {
            isProcessing = true; progress = 0
            statusMessage = "جاري فك ضغط IPA..."
        }
        try fileManager.unzipItem(at: url, to: dest)
        await MainActor.run { progress = 0.5; statusMessage = "جاري قراءة Info.plist..." }
        let info = try parseIPAInfo(at: dest)
        await MainActor.run {
            self.ipaInfo = info; self.extractedPath = dest
            self.currentIPAPath = url; self.progress = 1.0
            self.isProcessing = false
            self.statusMessage = "تم فك الضغط بنجاح ✅"
        }
        return dest
    }

    func parseIPAInfo(at extractedDir: URL) throws -> IPAInfo {
        let payloadDir = extractedDir.appendingPathComponent("Payload")
        let appDirs = try fileManager.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appDir = appDirs.first else { throw IPAError.noAppBundle }
        let plistURL = appDir.appendingPathComponent("Info.plist")
        guard let plistData = fileManager.contents(atPath: plistURL.path),
              let plist = try PropertyListSerialization.propertyList(
                from: plistData, format: nil) as? [String: Any]
        else { throw IPAError.invalidPlist }
        let dylibPaths = try findEmbeddedDylibs(in: appDir)
        let entitlements = (try? parseEntitlements(in: appDir)) ?? [:]
        let iconData = loadIcon(from: appDir, plist: plist)
        return IPAInfo(
            bundleID: plist["CFBundleIdentifier"] as? String ?? "",
            displayName: plist["CFBundleDisplayName"] as? String
                ?? plist["CFBundleName"] as? String ?? "",
            version: plist["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: plist["CFBundleVersion"] as? String ?? "",
            minOSVersion: plist["MinimumOSVersion"] as? String ?? "",
            executableName: plist["CFBundleExecutable"] as? String ?? "",
            teamID: entitlements["com.apple.developer.team-identifier"] as? String,
            entitlements: entitlements, embeddedDylibs: dylibPaths,
            iconData: iconData, plistData: plist)
    }

    func findEmbeddedDylibs(in appDir: URL) throws -> [String] {
        var dylibs: [String] = []
        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        if fileManager.fileExists(atPath: frameworksDir.path) {
            let contents = try fileManager.contentsOfDirectory(
                at: frameworksDir, includingPropertiesForKeys: nil)
            for item in contents {
                if item.pathExtension == "dylib" || item.pathExtension == "framework" {
                    dylibs.append(item.lastPathComponent)
                }
            }
        }
        return Array(Set(dylibs))
    }

    func parseExecutableName(from appDir: URL) -> String? {
        let plistURL = appDir.appendingPathComponent("Info.plist")
        guard let data = fileManager.contents(atPath: plistURL.path),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleExecutable"] as? String
    }

    func parseEntitlements(in appDir: URL) throws -> [String: Any] {
        let execName = parseExecutableName(from: appDir) ?? ""
        let execPath = appDir.appendingPathComponent(execName)
        guard let data = fileManager.contents(atPath: execPath.path) else { return [:] }
        let xmlMagic = Data("<?xml".utf8)
        var searchRange = data.startIndex..<data.endIndex
        while let range = data.range(of: xmlMagic, in: searchRange) {
            let slice = data[range.lowerBound...]
            if let endRange = slice.range(of: Data("</plist>".utf8)) {
                let plistSlice = slice[slice.startIndex...endRange.upperBound]
                if let plist = try? PropertyListSerialization.propertyList(
                    from: plistSlice, format: nil) as? [String: Any] {
                    if plist.keys.contains(where: {
                        $0.contains("apple") || $0.contains("keychain") }) {
                        return plist
                    }
                }
            }
            searchRange = range.upperBound..<data.endIndex
        }
        return [:]
    }

    func loadIcon(from appDir: URL, plist: [String: Any]) -> Data? {
        if let icons = plist["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastName = files.last {
            for candidate in ["\(lastName)@3x.png", "\(lastName)@2x.png", "\(lastName).png"] {
                if let data = try? Data(contentsOf: appDir.appendingPathComponent(candidate)) {
                    return data
                }
            }
        }
        if let contents = try? fileManager.contentsOfDirectory(
            at: appDir, includingPropertiesForKeys: nil) {
            let icons = contents.filter {
                $0.lastPathComponent.contains("AppIcon") && $0.pathExtension == "png"
            }
            if let icon = icons.sorted(
                by: { $0.lastPathComponent > $1.lastPathComponent }).first {
                return try? Data(contentsOf: icon)
            }
        }
        return nil
    }

    func injectDylib(dylibURL: URL, into ipaExtractedURL: URL) async throws {
        await MainActor.run { isProcessing = true; statusMessage = "جاري حقن المكتبة..." }
        let payloadDir = ipaExtractedURL.appendingPathComponent("Payload")
        let appDirs = try fileManager.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appDir = appDirs.first else { throw IPAError.noAppBundle }
        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        try fileManager.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
        let destURL = frameworksDir.appendingPathComponent(dylibURL.lastPathComponent)
        try? fileManager.removeItem(at: destURL)
        try fileManager.copyItem(at: dylibURL, to: destURL)
        let execName = parseExecutableName(from: appDir) ?? ""
        let execURL = appDir.appendingPathComponent(execName)
        try insertLoadDylibCommand(
            execURL: execURL,
            dylibPath: "@executable_path/Frameworks/\(dylibURL.lastPathComponent)")
        await MainActor.run { isProcessing = false; statusMessage = "تم حقن المكتبة بنجاح ✅" }
    }

    func insertLoadDylibCommand(execURL: URL, dylibPath: String) throws {
        guard var data = fileManager.contents(atPath: execURL.path) else {
            throw IPAError.executableNotFound
        }
        let pathBytes = Array(dylibPath.utf8) + [0]
        var nameOffset: UInt32 = 24
        let rawSize = Int(nameOffset) + pathBytes.count
        var cmdSize = UInt32((rawSize + 7) & ~7)
        var cmdBytes = [UInt8](repeating: 0, count: Int(cmdSize))
        var cmd: UInt32 = 0xC
        var timestamp: UInt32 = 2
        var currentVersion: UInt32 = 0x10000
        var compatVersion: UInt32 = 0x10000
        withUnsafeBytes(of: &cmd)            { cmdBytes.replaceSubrange(0..<4,   with: $0) }
        withUnsafeBytes(of: &cmdSize)        { cmdBytes.replaceSubrange(4..<8,   with: $0) }
        withUnsafeBytes(of: &nameOffset)     { cmdBytes.replaceSubrange(8..<12,  with: $0) }
        withUnsafeBytes(of: &timestamp)      { cmdBytes.replaceSubrange(12..<16, with: $0) }
        withUnsafeBytes(of: &currentVersion) { cmdBytes.replaceSubrange(16..<20, with: $0) }
        withUnsafeBytes(of: &compatVersion)  { cmdBytes.replaceSubrange(20..<24, with: $0) }
        cmdBytes.replaceSubrange(24..<(24 + pathBytes.count), with: pathBytes)
        data.append(contentsOf: cmdBytes)
        data.withUnsafeMutableBytes { ptr in
            let base = ptr.baseAddress!.assumingMemoryBound(to: UInt32.self)
            base[4] += 1; base[5] += cmdSize
        }
        try data.write(to: execURL)
    }

    func editPlist(key: String, value: Any, in ipaExtractedURL: URL) throws {
        let payloadDir = ipaExtractedURL.appendingPathComponent("Payload")
        let appDirs = try fileManager.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appDir = appDirs.first else { throw IPAError.noAppBundle }
        let plistURL = appDir.appendingPathComponent("Info.plist")
        guard let data = fileManager.contents(atPath: plistURL.path),
              var plist = try PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any]
        else { throw IPAError.invalidPlist }
        plist[key] = value
        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: plistURL)
    }

    func removeDylib(named name: String, from ipaExtractedURL: URL) throws {
        let payloadDir = ipaExtractedURL.appendingPathComponent("Payload")
        let appDirs = try fileManager.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appDir = appDirs.first else { throw IPAError.noAppBundle }
        try? fileManager.removeItem(
            at: appDir.appendingPathComponent("Frameworks")
                .appendingPathComponent(name))
    }

    func repackIPA(from extractedURL: URL, outputName: String) async throws -> URL {
        await MainActor.run { isProcessing = true; statusMessage = "جاري إعادة حزم IPA..." }
        let outputURL = workDir.appendingPathComponent("\(outputName).ipa")
        try? fileManager.removeItem(at: outputURL)
        try fileManager.zipItem(at: extractedURL, to: outputURL)
        await MainActor.run { isProcessing = false; statusMessage = "تم إنشاء IPA بنجاح ✅" }
        return outputURL
    }

    func signIPA(
        extractedURL: URL, certificate: Certificate,
        bundleIDOverride: String?, entitlementsOverride: [String: Any]?
    ) async throws -> URL {
        await MainActor.run { isProcessing = true; statusMessage = "جاري التوقيع..." }
        if let newID = bundleIDOverride {
            try editPlist(key: "CFBundleIdentifier", value: newID, in: extractedURL)
        }
        let entitlements = entitlementsOverride ?? certificate.entitlementsForSigning
        let entitlementsURL = workDir.appendingPathComponent("entitlements.plist")
        let entData = try PropertyListSerialization.data(
            fromPropertyList: entitlements, format: .xml, options: 0)
        try entData.write(to: entitlementsURL)
        let payloadDir = extractedURL.appendingPathComponent("Payload")
        let appDirs = try fileManager.contentsOfDirectory(
            at: payloadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appDir = appDirs.first else { throw IPAError.noAppBundle }
        if let provData = certificate.provisionData {
            try provData.write(
                to: appDir.appendingPathComponent("embedded.mobileprovision"))
        }
        await MainActor.run { progress = 0.8; statusMessage = "جاري إعادة الحزم..." }
        let outputURL = try await repackIPA(
            from: extractedURL,
            outputName: "\(ipaInfo?.displayName ?? "app")_signed")
        await MainActor.run { isProcessing = false; statusMessage = "تم التوقيع بنجاح ✅" }
        return outputURL
    }
}

enum IPAError: LocalizedError {
    case noAppBundle, invalidPlist, executableNotFound, signingFailed(String)
    var errorDescription: String? {
        switch self {
        case .noAppBundle: return "لم يتم العثور على App Bundle"
        case .invalidPlist: return "ملف Info.plist غير صالح"
        case .executableNotFound: return "لم يتم العثور على الملف التنفيذي"
        case .signingFailed(let m): return "فشل التوقيع: \(m)"
        }
    }
}

extension Certificate {
    var entitlementsForSigning: [String: Any] {
        ["com.apple.developer.team-identifier": teamID,
         "application-identifier": "\(teamID).*",
         "get-task-allow": true]
    }
}
