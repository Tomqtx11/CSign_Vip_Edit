//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				if !Zsign.removeDylibs(appExecutable: execPath, using: self._options.disInjectionFiles) {
					continuation.resume(throwing: SigningFileHandlerError.disinjectFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				let success = Zsign.sign(
					appPath: self._appUrl.relativePath,
					provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
					p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
					p12Password: cert.password ?? "",
					entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
					removeProvision: !self._options.removeProvisioning,
					completion: { _ in }
				)
				if !success {
					continuation.resume(throwing: SigningFileHandlerError.signFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
	
	func adhocSign() async throws {
		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				let success = Zsign.sign(
					appPath: self._appUrl.relativePath,
					entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
					adhoc: true,
					removeProvision: !self._options.removeProvisioning,
					completion: { _ in }
				)
				if !success {
					continuation.resume(throwing: SigningFileHandlerError.signFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
}
