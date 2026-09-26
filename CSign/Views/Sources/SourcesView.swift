//
//  SourcesView.swift
//  CSign
//
//  Created by samara on 10.04.2025.
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
	@State private var _addingSourceLoading = false
	@State private var _searchText = ""
	
	private var _filteredSources: [AltSource] {
		_sources.filter { _searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false) }
	}
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Sources")) {
			NBListAdaptable {
				// MARK: - Fixed Banners (Mua Chứng Chỉ & Tham gia cộng đồng)
				Section {
					_fixedBanners()
				}
				.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
				
				if !_filteredSources.isEmpty {
					Section {
						NavigationLink {
							SourceAppsView(object: Array(_sources), viewModel: viewModel)
						} label: {
							let isRegular = horizontalSizeClass != .compact
							HStack(spacing: 18) {
								Image("Repositories").appIconStyle()
								NBTitleWithSubtitleView(
									title: .localized("All Repositories"),
									subtitle: .localized("See all apps from your sources")
								)
							}
							.padding(isRegular ? 12 : 0)
							.background(
								isRegular
									? RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(Color(.quaternarySystemFill))
									: nil
							)
						}
						.buttonStyle(.plain)
					}
					
					NBSection(
						.localized("Repositories"),
						secondary: _filteredSources.count.description
					) {
						ForEach(_filteredSources) { source in
							NavigationLink {
								SourceAppsView(object: [source], viewModel: viewModel)
							} label: {
								SourcesCellView(source: source)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform())
			.overlay {
				if _filteredSources.isEmpty {
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label(.localized("No Repositories"), systemImage: "globe.desk.fill")
						} description: {
							Text(.localized("Get started by adding your first repository."))
						} actions: {
							Button {
								_isAddingPresenting = true
							} label: {
								NBButton(.localized("Add Source"), style: .text)
							}
						}
					}
				}
			}
			.toolbar {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing,
					isDisabled: _addingSourceLoading
				) {
					_isAddingPresenting = true
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
		
	}
}

// MARK: - Extension: Fixed Banners
extension SourcesView {
	// URL ảnh banner từ GitHub (đã có sẵn trong repo)
	private static let banner1URL = URL(string: "https://raw.githubusercontent.com/Tomqtx11/CSign/main/CSign/Resources/RepoImage1.jpg")!
	private static let banner2URL = URL(string: "https://raw.githubusercontent.com/Tomqtx11/CSign/main/CSign/Resources/RepoImage2.jpg")!
	
	/// 2 banner cố định: Mua Chứng Chỉ & Tham gia cộng đồng
	@ViewBuilder
	private func _fixedBanners() -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				_bannerCard(
					imageURL: SourcesView.banner1URL,
					title: "🛒 Mua Chứng Chỉ",
					url: URL(string: "https://cuios.shop")!
				)
				_bannerCard(
					imageURL: SourcesView.banner2URL,
					title: "👥 Tham Gia Cộng Đồng",
					url: URL(string: "https://t.me/chungchicuios")!
				)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
		}
	}
	
	/// Một card banner: ảnh từ URL + tiêu đề + bấm mở link
	@ViewBuilder
	private func _bannerCard(
		imageURL: URL,
		title: String,
		url: URL
	) -> some View {
		Button {
			UIApplication.shared.open(url)
		} label: {
			ZStack(alignment: .bottomLeading) {
				// Ảnh banner load từ GitHub
				LazyImage(url: imageURL) { state in
					if let image = state.image {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
					} else {
						Color(.systemFill)
							.overlay(
								state.isLoading
									? AnyView(ProgressView())
									: AnyView(EmptyView())
							)
					}
				}
				.frame(width: 280, height: 130)
				.clipped()
				
				// Gradient overlay để text dễ đọc
				LinearGradient(
					colors: [.clear, .black.opacity(0.7)],
					startPoint: .top,
					endPoint: .bottom
				)
				
				// Text overlay
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.system(size: 14, weight: .bold))
						.foregroundColor(.white)
						.shadow(radius: 2)
				}
				.padding(10)
			}
			.frame(width: 280, height: 130)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
		}
		.buttonStyle(.plain)
	}
}
