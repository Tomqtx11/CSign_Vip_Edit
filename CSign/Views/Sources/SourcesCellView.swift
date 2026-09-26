//
//  SourcesCellView.swift
//  CSign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	
	var source: AltSource
	
	// MARK: Body
	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		
		FRIconCellView(
			title: source.name ?? .localized("Unknown"),
			subtitle: "Kho ứng dụng",
			iconUrl: source.iconURL
		)
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
				? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(Color(.quaternarySystemFill))
				: nil
		)
		.swipeActions {
			_actions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
	}
}
