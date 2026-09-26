//
//  SigningHandler.swift
//  CSign
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import UIKit
import OSLog

final class SigningHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _movedAppPath: URL?
	// using uuid string is the best way to find the
	// app we want to sign, it does not matter what
	// type of app it is
	private var _app: AppInfoPresentable
	private var _options: Options
	private let _uniqueWorkDir: URL
	// the options struct is not gonna decode these so
	// we're just going to do this. If appicon is not
	// specified, we're not going to modify the app
	// icon. If the cert pair is not there, fallback
	// to adhoc signing (if the option is on, otherwise
	// throw an error
	var appIcon: UIImage?
	var appCertificate: CertificatePair?
	
	init(app: AppInfoPresentable, options: Options = OptionsManager.shared.options) {
		self._app = app
		self._options = options
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("CSignSigning_\(_uuid)", isDirectory: true)
		super.init()
	}
	
	/// Check if signing has been cancelled
	private func checkCancelled() throws {
		if LogCapture.isCancelledSync {
			throw SigningFileHandlerError.cancelled
		}
	}
	
	func copy() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}

		try checkCancelled()
		
		LogCapture.shared.setPhase(.copying)
		
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
					try self.checkCancelled()
                    try self._fileManager.createDirectoryIfNeeded(at: self._uniqueWorkDir)
                    
                    LogCapture.shared.printLog("📁 Tạo thư mục bộ nhớ đệm...")
					LogCapture.shared.updateProgress(phase: .copying, subProgress: 0.05)
					
                    let movedAppURL = self._uniqueWorkDir.appendingPathComponent(appUrl.lastPathComponent)
                    
					// Calculate total size for progress
					let totalSize = self.calculateDirectorySize(url: appUrl)
					LogCapture.shared.printLog("📋 Kích thước app: \(self.formatBytes(totalSize))")
					LogCapture.shared.updateProgress(phase: .copying, subProgress: 0.1)
					
					LogCapture.shared.printLog("📦 Đang sao chép tệp .app...")
					
					// Use streaming copy with progress for large apps
					if totalSize > 50_000_000 { // > 50MB
						try self.copyDirectoryWithProgress(from: appUrl, to: movedAppURL, totalSize: totalSize)
					} else {
						try self._fileManager.copyItem(at: appUrl, to: movedAppURL)
						LogCapture.shared.updateProgress(phase: .copying, subProgress: 1.0)
					}
					
                    self._movedAppPath = movedAppURL
					LogCapture.shared.printLog("✅ Sao chép hoàn tất.")
                    Logger.misc.info("[\(self._uuid)] Moved Payload to: \(movedAppURL.path)")
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
	}
	
	/// Copy directory with progress reporting for large apps
	private func copyDirectoryWithProgress(from source: URL, to destination: URL, totalSize: Int64) throws {
		try _fileManager.createDirectoryIfNeeded(at: destination)
		
		var copiedSize: Int64 = 0
		var lastReportedPercent: Int = 0
		let startTime = CFAbsoluteTimeGetCurrent()
		
		let enumerator = _fileManager.enumerator(at: source,
			includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
			options: [.skipsHiddenFiles])
		
		while let fileURL = enumerator?.nextObject() as? URL {
			if LogCapture.isCancelledSync {
				throw SigningFileHandlerError.cancelled
			}
			
			let relativePath = fileURL.path.replacingOccurrences(of: source.path, with: "")
			let destURL = destination.appendingPathComponent(relativePath)
			
			let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
			
			if resourceValues.isDirectory == true {
				try _fileManager.createDirectoryIfNeeded(at: destURL)
			} else {
				let parentDir = destURL.deletingLastPathComponent()
				try _fileManager.createDirectoryIfNeeded(at: parentDir)
				try _fileManager.copyItem(at: fileURL, to: destURL)
				copiedSize += Int64(resourceValues.fileSize ?? 0)
			}
			
			// Report progress every 1%
			let currentPercent = totalSize > 0 ? Int(Double(copiedSize) / Double(totalSize) * 100) : 0
			if currentPercent > lastReportedPercent {
				lastReportedPercent = currentPercent
				let progressValue = Double(copiedSize) / Double(totalSize)
				LogCapture.shared.updateProgress(phase: .copying, subProgress: 0.1 + progressValue * 0.9)
				
				// Log every 10%
				if currentPercent % 10 == 0 {
					let elapsed = CFAbsoluteTimeGetCurrent() - startTime
					let speed = elapsed > 0 ? Double(copiedSize) / elapsed / 1_000_000 : 0
					LogCapture.shared.printLog("   ↳ Sao chép: \(currentPercent)% (\(self.formatBytes(copiedSize))/\(self.formatBytes(totalSize))) - \(String(format: "%.1f", speed)) MB/s")
				}
			}
		}
	}
	
	func modify() async throws {
		try checkCancelled()
		LogCapture.shared.setPhase(.modifying)
		LogCapture.shared.printLog("⚙️ Chuẩn bị tuỳ chỉnh ứng dụng...")
		guard let movedAppPath = _movedAppPath else {
			throw SigningFileHandlerError.appNotFound
		}
		
		guard
			let infoDictionary = NSDictionary(
				contentsOf: movedAppPath.appendingPathComponent("Info.plist")
			)!.mutableCopy() as? NSMutableDictionary
		else {
			throw SigningFileHandlerError.infoPlistNotFound
		}
		
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.1)
		
		if
			let identifier = _options.appIdentifier,
			let oldIdentifier = infoDictionary["CFBundleIdentifier"] as? String
		{
			LogCapture.shared.printLog("   ↳ Cập nhật Bundle ID các plugin...")
			try await _modifyPluginIdentifiers(old: oldIdentifier, new: identifier, for: movedAppPath)
		}
		
		try checkCancelled()
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.2)
		LogCapture.shared.printLog("   ↳ Cập nhật Info.plist...")
		try await _modifyDict(using: infoDictionary, with: _options, to: movedAppPath)
		
		if let icon = appIcon {
			LogCapture.shared.printLog("   ↳ Thay đổi icon ứng dụng...")
			try await _modifyDict(using: infoDictionary, for: icon, to: movedAppPath)
		}
		
		if let name = _options.appName {
			LogCapture.shared.printLog("   ↳ Đổi tên hiển thị...")
			try await _modifyLocalesForName(name, for: movedAppPath)
		}
		
		try checkCancelled()
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.4)
		
		if !_options.removeFiles.isEmpty {
			LogCapture.shared.printLog("   ↳ Xoá \(_options.removeFiles.count) file không cần thiết...")
			try await _removeFiles(for: movedAppPath, from: _options.removeFiles)
		}
		
		try await _removePresetFiles(for: movedAppPath)
		try await _removeWatchIfNeeded(for: movedAppPath)
		
		try checkCancelled()
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.5)
		
		if _options.experiment_supportLiquidGlass {
			LogCapture.shared.printLog("   ↳ Hỗ trợ Liquid Glass (SDK 26)...")
			try await _locateMachosAndChangeToSDK26(for: movedAppPath)
		}
		
		if _options.experiment_replaceSubstrateWithEllekit {
			LogCapture.shared.printLog("   ↳ Tiêm tweak (Ellekit)...")
			try await _inject(for: movedAppPath, with: _options)
		} else {
			if !_options.injectionFiles.isEmpty {
				LogCapture.shared.printLog("   ↳ Tiêm \(_options.injectionFiles.count) dylib...")
				try await _inject(for: movedAppPath, with: _options)
			}
		}
		
		try checkCancelled()
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.6)
		
		// iOS "26" (19) needs special treatment
		LogCapture.shared.printLog("   ↳ Fixup ARM64e slices...")
		try await _locateMachosAndFixupArm64eSlice(for: movedAppPath)
		
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.7)
		
		let handler = ZsignHandler(appUrl: movedAppPath, options: _options, cert: appCertificate)
		if !_options.disInjectionFiles.isEmpty {
			LogCapture.shared.printLog("🗑 Đang gỡ bỏ (Disinject) \(_options.disInjectionFiles.count) thư viện...")
		}
		try await handler.disinject()
		
		try checkCancelled()
		LogCapture.shared.updateProgress(phase: .modifying, subProgress: 0.8)
		
			// MARK: - Signing Phase
		if
			_options.signingOption == .default,
			appCertificate != nil
		{
			LogCapture.shared.setPhase(.signing)
			LogCapture.shared.printLog("🔐 Bắt đầu ký ứng dụng...")
			LogCapture.shared.printLog("   ↳ Tính toán SHA hash cho tất cả file...")
			LogCapture.shared.updateProgress(phase: .signing, subProgress: 0.05)
			
			try await handler.sign()
			LogCapture.shared.updateProgress(phase: .signing, subProgress: 1.0)
			LogCapture.shared.printLog("✅ Ký hoàn tất!")
//		} else if _options.signingOption == .adhoc {
//			try await handler.adhocSign()
		} else if _options.signingOption == .onlyModify {
			LogCapture.shared.printLog("ℹ️ Chế độ chỉ tuỳ chỉnh (không ký).")
		} else {
			throw SigningFileHandlerError.missingCertifcate
		}
		
		try checkCancelled()
		
		// MARK: - Saving Phase
		LogCapture.shared.setPhase(.saving)
		LogCapture.shared.printLog("💾 Hoàn tất và lưu vào cơ sở dữ liệu...")
		LogCapture.shared.updateProgress(phase: .saving, subProgress: 0.2)
		try await self.move()
		LogCapture.shared.updateProgress(phase: .saving, subProgress: 0.7)
		try await self.addToDatabase()
		LogCapture.shared.updateProgress(phase: .saving, subProgress: 1.0)
		LogCapture.shared.printLog("✅ Đã lưu thành công!")
		
		if let error = handler.hadError {
			throw error
		}
	}
	
	func move() async throws {
		guard let movedAppPath = _movedAppPath else {
			throw SigningFileHandlerError.appNotFound
		}
		
		var destinationURL = try await _directory()
		
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self._fileManager.createDirectoryIfNeeded(at: destinationURL)
                    
                    let finalURL = destinationURL.appendingPathComponent(movedAppPath.lastPathComponent)
                    
                    try self._fileManager.moveItem(at: movedAppPath, to: finalURL)
                    Logger.misc.info("[\(self._uuid)] Moved App to: \(finalURL.path)")
                    
                    try? self._fileManager.removeItem(at: self._uniqueWorkDir)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
	}
	
	func addToDatabase() async throws {
		let app = try await _directory()
		
		guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
			return
		}
		
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			let bundle = Bundle(url: appUrl)
			
			Storage.shared.addSigned(
				uuid: _uuid,
				source: _app.source,
				certificate: _options.signingOption != .default ? nil : appCertificate,
				appName: bundle?.name,
				appIdentifier: bundle?.bundleIdentifier,
				appVersion: bundle?.version,
				appIcon: bundle?.iconFileName
			) { _ in
				Logger.signing.info("[\(self._uuid)] Added to database")
				continuation.resume()
			}
		}
		
		Storage.shared.copySourceMetadata(
			from: _app.uuid,
			to: _uuid,
			kind: .signed
		)
        
        if let encoded = try? JSONEncoder().encode(_options) {
            UserDefaults.standard.set(encoded, forKey: "csign_options_\(_uuid)")
        }
	}
	
	private func _directory() async throws -> URL {
		// Documents/CSign/Signed/\(UUID)
		_fileManager.signed(_uuid)
	}
	
	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
	}
	
	// MARK: - Utility
	
	private func calculateDirectorySize(url: URL) -> Int64 {
		var totalSize: Int64 = 0
		if let enumerator = _fileManager.enumerator(at: url,
			includingPropertiesForKeys: [.fileSizeKey],
			options: [.skipsHiddenFiles]) {
			for case let fileURL as URL in enumerator {
				if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
					totalSize += Int64(fileSize)
				}
			}
		}
		return totalSize
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let mb = Double(bytes) / 1_000_000
		if mb > 1000 {
			return String(format: "%.1f GB", mb / 1000)
		}
		return String(format: "%.1f MB", mb)
	}
}

extension SigningHandler {
	private func _modifyDict(using infoDictionary: NSMutableDictionary, with options: Options, to app: URL) async throws {
		if options.fileSharing { infoDictionary.setObject(true, forKey: "UISupportsDocumentBrowser" as NSCopying) }
		if options.itunesFileSharing { infoDictionary.setObject(true, forKey: "UIFileSharingEnabled" as NSCopying) }
		if options.proMotion { infoDictionary.setObject(true, forKey: "CADisableMinimumFrameDurationOnPhone" as NSCopying) }
		if options.gameMode { infoDictionary.setObject(true, forKey: "GCSupportsGameMode" as NSCopying)}
		if options.ipadFullscreen { infoDictionary.setObject(true, forKey: "UIRequiresFullScreen" as NSCopying) }
		if options.removeURLScheme { infoDictionary.removeObject(forKey: "CFBundleURLTypes") }
		
		if options.appAppearance != .default {
			infoDictionary.setObject(options.appAppearance.rawValue, forKey: "UIUserInterfaceStyle" as NSCopying)
		}
		if options.minimumAppRequirement != .default {
			infoDictionary.setObject(options.minimumAppRequirement.rawValue, forKey: "MinimumOSVersion" as NSCopying)
		}
		
		if options.experiment_disableLiquidGlass { infoDictionary.setObject(true, forKey: "UIDesignRequiresCompatibility" as NSCopying) }
		if options.experiment_supportLiquidGlass { infoDictionary.setObject(false, forKey: "UIDesignRequiresCompatibility" as NSCopying) }
		
		// useless crap
		if infoDictionary["UISupportedDevices"] != nil {
			infoDictionary.removeObject(forKey: "UISupportedDevices")
		}
		
		// MARK: Prominant values
		
		if let customIdentifier = options.appIdentifier, !customIdentifier.isEmpty {
			infoDictionary.setObject(customIdentifier, forKey: "CFBundleIdentifier" as NSCopying)
		}
		if let customName = options.appName, !customName.isEmpty {
			infoDictionary.setObject(customName, forKey: "CFBundleDisplayName" as NSCopying)
			infoDictionary.setObject(customName, forKey: "CFBundleName" as NSCopying)
		}
		if let customVersion = options.appVersion, !customVersion.isEmpty {
			infoDictionary.setObject(customVersion, forKey: "CFBundleShortVersionString" as NSCopying)
			infoDictionary.setObject(customVersion, forKey: "CFBundleVersion" as NSCopying)
		}
		
		try infoDictionary.write(to: app.appendingPathComponent("Info.plist"))
	}
	
	private func _modifyDict(using infoDictionary: NSMutableDictionary, for image: UIImage, to app: URL) async throws {
		let imageSizes = [
			(width: 120, height: 120, name: "FRIcon60x60@2x.png"),
			(width: 152, height: 152, name: "FRIcon76x76@2x~ipad.png")
		]
		
		for imageSize in imageSizes {
			let resizedImage = image.resize(imageSize.width, imageSize.height)
			let imageData = resizedImage.pngData()
			let fileURL = app.appendingPathComponent(imageSize.name)
			
			try imageData?.write(to: fileURL)
		}
		
		let cfBundleIcons: [String: Any] = [
			"CFBundlePrimaryIcon": [
				"CFBundleIconFiles": ["FRIcon60x60"],
				"CFBundleIconName": "FRIcon"
			]
		]
		
		let cfBundleIconsIpad: [String: Any] = [
			"CFBundlePrimaryIcon": [
				"CFBundleIconFiles": ["FRIcon60x60", "FRIcon76x76"],
				"CFBundleIconName": "FRIcon"
			]
		]
		
		infoDictionary["CFBundleIcons"] = cfBundleIcons
		infoDictionary["CFBundleIcons~ipad"] = cfBundleIconsIpad
		
		try infoDictionary.write(to: app.appendingPathComponent("Info.plist"))
	}
	
	private func _modifyLocalesForName(_ name: String, for app: URL) async throws {
		let localizationBundles = try _fileManager
			.contentsOfDirectory(at: app, includingPropertiesForKeys: nil)
			.filter { $0.pathExtension == "lproj" }
		
		localizationBundles.forEach { bundleURL in
			let plistURL = bundleURL.appendingPathComponent("InfoPlist.strings")
			
			guard
				_fileManager.fileExists(atPath: plistURL.path),
				let dictionary = NSMutableDictionary(contentsOf: plistURL)
			else {
				return
			}
			
			dictionary["CFBundleDisplayName"] = name
			dictionary.write(toFile: plistURL.path, atomically: true)
		}
	}
	
	private func _modifyPluginIdentifiers(
		old oldIdentifier: String,
		new newIdentifier: String,
		for app: URL
	) async throws {
		let pluginBundles = _enumerateFiles(at: app) {
			$0.hasSuffix(".app") || $0.hasSuffix(".appex")
		}
		
		for bundleURL in pluginBundles {
			let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
			
			guard let infoDict = NSDictionary(contentsOf: infoPlistURL)?.mutableCopy() as? NSMutableDictionary else {
				continue
			}
			
			var didChange = false
			
			// CFBundleIdentifier
			if let oldValue = infoDict["CFBundleIdentifier"] as? String {
				let newValue = oldValue.replacingOccurrences(of: oldIdentifier, with: newIdentifier)
				if oldValue != newValue {
					infoDict["CFBundleIdentifier"] = newValue
					didChange = true
				}
			}
			
			// WKCompanionAppBundleIdentifier
			if let oldValue = infoDict["WKCompanionAppBundleIdentifier"] as? String {
				let newValue = oldValue.replacingOccurrences(of: oldIdentifier, with: newIdentifier)
				if oldValue != newValue {
					infoDict["WKCompanionAppBundleIdentifier"] = newValue
					didChange = true
				}
			}
			if let extensionDict = (infoDict["NSExtension"] as? NSDictionary)?.mutableCopy() as? NSMutableDictionary {
				// NSExtension → NSExtensionAttributes → WKAppBundleIdentifier
				if
					let attributes = extensionDict["NSExtensionAttributes"] as? NSMutableDictionary,
					let oldValue = attributes["WKAppBundleIdentifier"] as? String
				{
					let newValue = oldValue.replacingOccurrences(of: oldIdentifier, with: newIdentifier)
					if oldValue != newValue {
						attributes["WKAppBundleIdentifier"] = newValue
						didChange = true
					}
				}
                
				// NSExtension → NSExtensionFileProviderDocumentGroup
				if
					let oldValue = extensionDict["NSExtensionFileProviderDocumentGroup"] as? String
				{
					let newValue = oldValue.replacingOccurrences(of: oldIdentifier, with: newIdentifier)
					if oldValue != newValue {
						extensionDict["NSExtensionFileProviderDocumentGroup"] = newValue
						didChange = true
					}
				}
                
				infoDict["NSExtension"] = extensionDict
			}
			
			if didChange {
				infoDict.write(to: infoPlistURL, atomically: true)
			}
		}
	}
	
	private func _removePresetFiles(for app: URL) async throws {
		var files = [
			"_CodeSignature", // Fallback for some reason the locate doesnt work
			"embedded.mobileprovision", // Remove this because zsign doesn't replace it
			"com.apple.WatchPlaceholder", // Useless
			"SignedByEsign" // Useless
		].map {
			app.appendingPathComponent($0)
		}
		
		await files += try _locateCodeSignatureDirectories(for: app)
		
		for file in files {
			try _fileManager.removeFileIfNeeded(at: file)
		}
	}
	
	// horrible edge-case
	private func _removeWatchIfNeeded(for app: URL) async throws {
		let watchDir = app.appendingPathComponent("Watch")
		guard _fileManager.fileExists(atPath: watchDir.path) else { return }
		
		let contents = try _fileManager.contentsOfDirectory(at: watchDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
		
		for app in contents where app.pathExtension == "app" {
			let infoPlist = app.appendingPathComponent("Info.plist")
			if !_fileManager.fileExists(atPath: infoPlist.path) {
				try? _fileManager.removeItem(at: app)
			}
		}
	}
	
	private func _removeFiles(for app: URL, from appendingComponent: [String]) async throws {
		let filesToRemove = appendingComponent.map {
			app.appendingPathComponent($0)
		}
		
		for url in filesToRemove {
			try _fileManager.removeFileIfNeeded(at: url)
		}
	}
	
	private func _inject(for app: URL, with options: Options) async throws {
		let handler = TweakHandler(app: app, options: options)
		try await handler.getInputFiles()
	}
	
	private func _locateMachosAndChangeToSDK26(for app: URL) async throws {
		if let url = Bundle(url: app)?.executableURL {
			LCPatchMachOForSDK26(app.appendingPathComponent(url.relativePath).relativePath)
		}
	}
	
	private func _locateCodeSignatureDirectories(for app: URL) async throws -> [URL] {
		_enumerateFiles(at: app) { $0.hasSuffix("_CodeSignature") }
	}
	
	private func _locateMachosAndFixupArm64eSlice(for app: URL) async throws {
		let machoFiles = _enumerateFiles(at: app) {
			$0.hasSuffix(".dylib") || $0.hasSuffix(".framework")
		}
		
		for fileURL in machoFiles {
			switch fileURL.pathExtension {
			case "dylib":
				LCPatchMachOFixupARM64eSlice(fileURL.path)
			case "framework":
				if
					let bundle = Bundle(url: fileURL),
					let execURL = bundle.executableURL
				{
					LCPatchMachOFixupARM64eSlice(execURL.path)
				}
			default:
				continue
			}
		}
	}
	
	private func _enumerateFiles(at base: URL, where predicate: (String) -> Bool) -> [URL] {
		guard let fileEnum = _fileManager.enumerator(atPath: base.path) else {
			return []
		}
		
		var results: [URL] = []
		
		while let file = fileEnum.nextObject() as? String {
			if predicate(file) {
				results.append(base.appendingPathComponent(file))
			}
		}
		
		return results
	}
}

enum SigningFileHandlerError: Error, LocalizedError {
	case appNotFound
	case infoPlistNotFound
	case missingCertifcate
	case disinjectFailed
	case signFailed
	case cancelled
	
	var errorDescription: String? {
		switch self {
		case .appNotFound: "Unable to locate bundle path."
		case .infoPlistNotFound: "Unable to locate info.plist path."
		case .missingCertifcate: "No certificate was specified."
		case .disinjectFailed: "Removing mach-O load paths failed."
		case .signFailed: "Signing failed."
		case .cancelled: "Quá trình ký đã bị huỷ bởi người dùng."
		}
	}
}
