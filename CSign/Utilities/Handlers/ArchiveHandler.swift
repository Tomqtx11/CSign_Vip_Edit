//
//  ArchiveHandler.swift
//  CSign
//
//  Created by samara on 22.04.2025.
//

import Foundation
import UIKit.UIApplication
import Zip
import SwiftUI
import IDeviceSwift

final class ArchiveHandler: NSObject {
	private var _lastProgressTime: CFAbsoluteTime = 0
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _payloadUrl: URL?
	
	private var _app: AppInfoPresentable
	private let _uniqueWorkDir: URL
	
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = app
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("CSignInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func move() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let payloadUrl = _uniqueWorkDir.appendingPathComponent("Payload")
		let movedAppURL = payloadUrl.appendingPathComponent(appUrl.lastPathComponent)

		try _fileManager.createDirectoryIfNeeded(at: payloadUrl)
		
		try _fileManager.copyItem(at: appUrl, to: movedAppURL)
		
		_payloadUrl = payloadUrl
	}
	
	func archive(forceNoCompression: Bool = false) async throws -> URL {
        let payloadUrl = self._payloadUrl
        guard let pUrl = payloadUrl else {
            throw SigningFileHandlerError.appNotFound
        }
        let zipUrl = self._uniqueWorkDir.appendingPathComponent("Archive.zip")
        let ipaUrl = self._uniqueWorkDir.appendingPathComponent("Archive.ipa")
        let compression = forceNoCompression ? ZipCompression.NoCompression : (ZipCompression(rawValue: ArchiveHandler.getCompressionLevel()) ?? .DefaultCompression)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Zip.zipFiles(
                        paths: [pUrl],
                        zipFilePath: zipUrl,
                        password: nil,
                        compression: compression,
                        progress: { progress in
                            let currentTime = CFAbsoluteTimeGetCurrent()
                            if progress == 1.0 || (currentTime - self._lastProgressTime > 0.05) {
                                self._lastProgressTime = currentTime
                                Task { @MainActor in
                                    self.viewModel.packageProgress = progress
                                }
                            }
                        })
                    try FileManager.default.moveItem(at: zipUrl, to: ipaUrl)
                    continuation.resume(returning: ipaUrl)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
	}
	
	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		let appendingString = "\(_app.name!)_\(_app.version!)_\(Int(Date().timeIntervalSince1970)).ipa"
		let dest = _fileManager.archives.appendingPathComponent(appendingString)
		
		try? _fileManager.moveItem(
			at: package,
			to: dest
		)
		
		if shouldOpen {
			await MainActor.run {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
		}
		
		return dest
	}
	
	static func getCompressionLevel() -> Int {
		if UserDefaults.standard.object(forKey: "CSign.compressionLevel") == nil {
			return 2 // Default to DefaultCompression instead of NoCompression
		}
		return UserDefaults.standard.integer(forKey: "CSign.compressionLevel")
	}
}
