import SwiftUI

struct SigningLogView: View {
	let app: AppInfoPresentable
	let options: Options
	let error: Error?
	var onDismiss: () -> Void
	
	@ObservedObject var logCapture = LogCapture.shared
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 0) {
			// MARK: - Header
			HStack {
				Text(.localized("Quá trình Ký"))
					.font(.headline)
				Spacer()
				if error == nil && logCapture.isCapturing {
					Button(action: {
						logCapture.cancel()
					}) {
						Text("Huỷ")
							.font(.headline)
							.foregroundColor(.red)
					}
				} else {
					Button(.localized("Đóng")) {
						dismiss()
						onDismiss()
					}
					.font(.headline)
					.foregroundColor(.accentColor)
				}
			}
			.padding()
			.background(Color(.secondarySystemBackground))
			
			// MARK: - Progress Section
			VStack(spacing: 10) {
				// Linear progress bar
				ProgressView(value: logCapture.progress)
					.progressViewStyle(LinearProgressViewStyle(tint: progressColor))
					.scaleEffect(y: 2.0, anchor: .center)
					.padding(.horizontal)
				
				HStack {
					// Phase label
					HStack(spacing: 6) {
						if logCapture.isCapturing && error == nil {
							Circle()
								.fill(progressColor)
								.frame(width: 8, height: 8)
								.modifier(PulseAnimation())
						}
						Text(phaseLabel)
							.font(.subheadline.bold())
							.foregroundColor(phaseLabelColor)
					}
					
					Spacer()
					
					// Percentage
					Text("\(Int(logCapture.progress * 100))%")
						.font(.system(.title2, design: .rounded).bold())
						.foregroundColor(progressColor)
						.contentTransition(.numericText())
						.animation(.easeInOut(duration: 0.15), value: Int(logCapture.progress * 100))
				}
				.padding(.horizontal)
			}
			.padding(.vertical, 12)
			.background(Color(.systemBackground))
			
			Divider()
			
			// MARK: - App Info
			VStack(alignment: .leading, spacing: 6) {
				HStack(spacing: 8) {
					Text("📦").font(.caption)
					Text(options.appName ?? app.name ?? "Không rõ")
						.font(.caption.bold())
					Spacer()
					Text("v\(options.appVersion ?? app.version ?? "?")")
						.font(.caption2)
						.foregroundColor(.secondary)
				}
				
				Text(options.appIdentifier ?? app.identifier ?? "Không rõ")
					.font(.system(.caption2, design: .monospaced))
					.foregroundColor(.secondary)
				
				if let error = error {
					HStack(spacing: 4) {
						Image(systemName: "xmark.circle.fill")
							.foregroundColor(.red)
						Text(error.localizedDescription)
							.font(.caption)
							.foregroundColor(.red)
					}
					.padding(.top, 4)
				} else if !logCapture.isCapturing && !logCapture.isCancelled {
					HStack(spacing: 4) {
						Image(systemName: "checkmark.circle.fill")
							.foregroundColor(.green)
						Text("Ký thành công!")
							.font(.caption.bold())
							.foregroundColor(.green)
					}
					.padding(.top, 4)
				} else if logCapture.isCancelled {
					HStack(spacing: 4) {
						Image(systemName: "xmark.circle.fill")
							.foregroundColor(.orange)
						Text("Đã huỷ quá trình ký")
							.font(.caption.bold())
							.foregroundColor(.orange)
					}
					.padding(.top, 4)
				}
			}
			.padding(.horizontal)
			.padding(.vertical, 8)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(.systemBackground))
			
			Divider()
			
			// MARK: - Console Logs (scrollable)
			ScrollViewReader { proxy in
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 2) {
						ForEach(Array(logCapture.logs.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
							Text(line)
								.font(.system(.caption2, design: .monospaced))
								.foregroundColor(logLineColor(for: line))
								.frame(maxWidth: .infinity, alignment: .leading)
								.id(index)
						}
					}
					.padding(10)
				}
				.background(Color(.secondarySystemBackground))
				.onChange(of: logCapture.logs) { _ in
					let lineCount = logCapture.logs.components(separatedBy: "\n").count - 1
					withAnimation(.easeOut(duration: 0.1)) {
						proxy.scrollTo(lineCount, anchor: .bottom)
					}
				}
			}
		}
		.onChange(of: logCapture.isCapturing) { isCapturing in
			if !isCapturing && error == nil && !logCapture.isCancelled {
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
					dismiss()
					onDismiss()
				}
			}
		}
	}
	
	// MARK: - Computed Properties
	
	private var progressColor: Color {
		if error != nil { return .red }
		if logCapture.isCancelled { return .orange }
		if !logCapture.isCapturing { return .green }
		return .accentColor
	}
	
	private var phaseLabel: String {
		if error != nil { return "❌ Lỗi" }
		if logCapture.isCancelled { return "⛔️ Đã huỷ" }
		if !logCapture.isCapturing { return "✅ Hoàn tất" }
		return logCapture.currentPhase.rawValue + "..."
	}
	
	private var phaseLabelColor: Color {
		if error != nil { return .red }
		if logCapture.isCancelled { return .orange }
		if !logCapture.isCapturing { return .green }
		return .primary
	}
	
	private func logLineColor(for line: String) -> Color {
		if line.contains("❌") || line.contains("Lỗi") || line.contains("Error") || line.contains("Failed") {
			return .red
		}
		if line.contains("✅") || line.contains("thành công") || line.contains("Hoàn tất") {
			return .green
		}
		if line.contains("⛔️") || line.contains("Huỷ") {
			return .orange
		}
		if line.contains("⚠️") || line.contains("Warning") {
			return .yellow
		}
		return .primary
	}
}

// MARK: - Pulse Animation Modifier
struct PulseAnimation: ViewModifier {
	@State private var isPulsing = false
	
	func body(content: Content) -> some View {
		content
			.opacity(isPulsing ? 0.3 : 1.0)
			.animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
			.onAppear { isPulsing = true }
	}
}
