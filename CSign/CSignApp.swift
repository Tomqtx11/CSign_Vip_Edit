//
//  CSignApp.swift
//  CSign
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog
import UserNotifications

@main
struct CSignApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	let heartbeat = HeartbeatManager.shared
	
	@StateObject var downloadManager = DownloadManager.shared
	let storage = Storage.shared
	@AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
	
	@Environment(\.scenePhase) var scenePhase
	@State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
	// Track if this is the very first render so disclaimer shows immediately
	@State private var _hasRendered = false

	var body: some Scene {
		WindowGroup {
			Group {
				if !hasAcceptedDisclaimer {
					// Show disclaimer immediately on first launch, no delay
					DisclaimerView(hasAcceptedDisclaimer: $hasAcceptedDisclaimer)
						.transition(.opacity)
				} else {
					VStack {
						DownloadHeaderView(downloadManager: downloadManager)
							.transition(.move(edge: .top).combined(with: .opacity))
						VariedTabbarView()
							.environment(\.managedObjectContext, storage.context)
							.onOpenURL(perform: _handleURL)
							.transition(.move(edge: .top).combined(with: .opacity))
					}
					.animation(.smooth, value: downloadManager.manualDownloads.description)
					.onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
						DispatchQueue.main.async {
							UIAlertController.showAlertWithOk(
								title: "InvalidHostID",
								message: .localized("Your pairing file is invalid and is incompatible with your device, please import a valid pairing file.")
							)
						}
					}
					// dear god help me
					.onAppear {
						if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "CSign.userInterfaceStyle")) {
							UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
						}
						
						UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: UserDefaults.standard.string(forKey: "CSign.userTintColor") ?? "#848ef9"))
					}
					.onChange(of: scenePhase) { newPhase in
						if newPhase == .background {
							if downloadManager.downloads.count > 0 {
								backgroundTask = UIApplication.shared.beginBackgroundTask {
									UIApplication.shared.endBackgroundTask(backgroundTask)
									backgroundTask = .invalid
								}
							}
						} else if newPhase == .active {
							if backgroundTask != .invalid {
								UIApplication.shared.endBackgroundTask(backgroundTask)
								backgroundTask = .invalid
							}
						}
					}
				}
			}
			.animation(.easeInOut(duration: 0.35), value: hasAcceptedDisclaimer)
		}
	}
	
	private func _handleURL(_ url: URL) {
		if url.scheme == "csign" {
			/// csign://import-certificate?p12=<base64>&mobileprovision=<base64>&password=<base64>
			if url.host == "import-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
					let queryItems = components.queryItems
				else {
					return
				}
				
				func queryValue(_ name: String) -> String? {
					queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding
				}
				
				guard
					let p12Base64 = queryValue("p12"),
					let provisionBase64 = queryValue("mobileprovision"),
					let passwordBase64 = queryValue("password"),
					let passwordData = Data(base64Encoded: passwordBase64),
					let password = String(data: passwordData, encoding: .utf8)
				else {
					return
				}
				
				let generator = UINotificationFeedbackGenerator()
				generator.prepare()
				
				guard
					let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"),
					let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"),
					FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL)
				else {
					generator.notificationOccurred(.error)
					return
				}
				
				FR.handleCertificateFiles(
					p12URL: p12URL,
					provisionURL: provisionURL,
					p12Password: password
				) { error in
					if let error = error {
						UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
					} else {
						generator.notificationOccurred(.success)
					}
				}
				
				return
			}
			/// csign://export-certificate?callback_template=<template>
			/// ?callback_template=: This is how we callback to the application requesting the certificate, this will be a url scheme
			/// 	example: livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29
			/// 	decoded: livecontainer://certificate?cert=$(BASE64_CERT)&password=$(PASSWORD)
			/// $(BASE64_CERT) and $(PASSWORD) must be presenting in the callback template so we can replace them with the proper content
			if url.host == "export-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
				else {
					return
				}
				
				let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
				guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
				
				FR.exportCertificateAndOpenUrl(using: callbackTemplate)
			}
			/// csign://source/<url>
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			/// csign://install/<url.ipa>
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				_ = DownloadManager.shared.startDownload(from: downloadURL)
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { _ in }
				} else {
					FR.handlePackageFile(url) { _ in }
				}
				
				return
			}
		}
	}
}

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
		_createPipeline()
		_createDocumentsDirectories()
		ResetView.clearWorkCache()
		_addDefaultCertificates()
		_addDefaultSources()
		return true
	}
	
	private func _createPipeline() {
		DataLoader.sharedUrlCache.diskCapacity = 0
		
		let pipeline = ImagePipeline {
			let dataLoader: DataLoader = {
				let config = URLSessionConfiguration.default
				config.urlCache = nil
				return DataLoader(configuration: config)
			}()
			let dataCache = try? DataCache(name: "thewonderofyou.CSign.datacache") // disk cache
			let imageCache = Nuke.ImageCache() // memory cache
			dataCache?.sizeLimit = 500 * 1024 * 1024
			imageCache.costLimit = 100 * 1024 * 1024
			$0.dataCache = dataCache
			$0.imageCache = imageCache
			$0.dataLoader = dataLoader
			$0.dataCachePolicy = .automatic
			$0.isStoringPreviewsInMemoryCache = false
		}
		
		ImagePipeline.shared = pipeline
	}
	
	private func _createDocumentsDirectories() {
		let fileManager = FileManager.default

		let directories: [URL] = [
			fileManager.archives,
			fileManager.certificates,
			fileManager.signed,
			fileManager.unsigned
		]
		
		for url in directories {
			try? fileManager.createDirectoryIfNeeded(at: url)
		}
	}
	
		private func _addDefaultSources() {
		let urlStr = "https://is.gd/17AE4t"
		if let url = URL(string: urlStr) {
			if let existing = Storage.shared.getSources().first(where: { $0.sourceURL?.absoluteString == urlStr }) {
				existing.name = "CSign IPA Repo"
				existing.iconURL = URL(string: "https://apptesters.org/apptesters-512x512.png")
				Storage.shared.saveContext()
			} else {
				Storage.shared.addSource(url, name: "CSign IPA Repo", identifier: url.absoluteString, iconURL: URL(string: "https://apptesters.org/apptesters-512x512.png")) { _ in }
			}
		}
		
		let unwantedUrlStr = "https://raw.githubusercontent.com/Tomqtx11/CSign/main/app-repo.json"
		if let unwanted = Storage.shared.getSources().first(where: { $0.sourceURL?.absoluteString == unwantedUrlStr }) {
			Storage.shared.deleteSource(for: unwanted)
		}
	}
	
	private func _addDefaultCertificates() {
		guard
			UserDefaults.standard.bool(forKey: "csign.didImportDefaultCertificates") == false,
			let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
		else {
			return
		}
		
		do {
			let folderContents = try FileManager.default.contentsOfDirectory(
				at: signingAssetsURL,
				includingPropertiesForKeys: nil,
				options: .skipsHiddenFiles
			)
			
			for folderURL in folderContents {
				guard folderURL.hasDirectoryPath else { continue }
				
				let certName = folderURL.lastPathComponent
				
				let p12Url = folderURL.appendingPathComponent("cert.p12")
				let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
				let passwordUrl = folderURL.appendingPathComponent("cert.txt")
				
				guard
					FileManager.default.fileExists(atPath: p12Url.path),
					FileManager.default.fileExists(atPath: provisionUrl.path),
					FileManager.default.fileExists(atPath: passwordUrl.path)
				else {
					Logger.misc.warning("Skipping \(certName): missing required files")
					continue
				}
				
				let password = try String(contentsOf: passwordUrl, encoding: .utf8)
				
				FR.handleCertificateFiles(
					p12URL: p12Url,
					provisionURL: provisionUrl,
					p12Password: password,
					certificateName: certName,
					isDefault: true
				) { _ in
					
				}
			}
			UserDefaults.standard.set(true, forKey: "csign.didImportDefaultCertificates")
		} catch {
			Logger.misc.error("Failed to list signing-assets: \(error)")
		}
	}

	private func _addDefaultTweaks() {
		guard UserDefaults.standard.bool(forKey: "csign.didImportDefaultTweaks") == false,
			  let builtInPath = Bundle.main.resourceURL?.appendingPathComponent("BuiltInTweaks")
		else { return }
		
		do {
			let folderContents = try FileManager.default.contentsOfDirectory(
				at: builtInPath,
				includingPropertiesForKeys: nil,
				options: .skipsHiddenFiles
			)
			
			let dylibs = folderContents.filter { $0.pathExtension == "dylib" }
			var added = false
			for dylib in dylibs {
				if !OptionsManager.shared.options.injectionFiles.contains(where: { $0.lastPathComponent == dylib.lastPathComponent }) {
					OptionsManager.shared.options.injectionFiles.append(dylib)
					added = true
				}
			}
			if added {
				OptionsManager.shared.saveOptions()
			}
			UserDefaults.standard.set(true, forKey: "csign.didImportDefaultTweaks")
		} catch {
			Logger.misc.error("Failed to list BuiltInTweaks: \(error)")
		}
	}
}
import SwiftUI
import NimbleViews

struct DisclaimerView: View {
    @Binding var hasAcceptedDisclaimer: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("Glyph")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                    
                    Text("⚠️ Điều khoản sử dụng")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 10)
                    
                    Text("Bằng việc sử dụng ứng dụng CSign, bạn đồng ý và cam kết:\n\n• Chỉ sử dụng cho mục đích cá nhân, nghiên cứu và học tập.\n• Không sử dụng để vi phạm bản quyền hoặc bất kỳ hành vi trái pháp luật nào.\n• Người dùng tự chịu hoàn toàn trách nhiệm về mọi hành vi khi sử dụng ứng dụng.\n• Nhà phát triển không chịu trách nhiệm cho bất kỳ thiệt hại nào phát sinh từ việc sử dụng.\n\nNếu bạn không đồng ý, vui lòng nhấn \"Từ chối\" để thoát ứng dụng.")
                        .font(.body)
                        .padding(.horizontal)
                        
                    Spacer(minLength: 40)
                    
                    VStack(spacing: 12) {
                        Button {
                            hasAcceptedDisclaimer = true
                        } label: {
                            Text("Đồng ý")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        
                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                exit(0)
                            }
                        } label: {
                            Text("Từ chối")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}
