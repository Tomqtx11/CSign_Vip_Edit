import Foundation
import Combine

private final class CancelState: @unchecked Sendable {
    let lock = NSLock()
    var flag = false
}
private let _cancelState = CancelState()

@MainActor
final class LogCapture: ObservableObject {
	static let shared = LogCapture()
	
	@Published var logs: String = ""
	@Published var isCapturing = false
	@Published var progress: Double = 0.0
	@Published var currentPhase: SigningPhase = .idle
	@Published var isCancelled = false
	
	/// Nonisolated thread-safe check for cancellation
	nonisolated static var isCancelledSync: Bool {
		_cancelState.lock.lock()
		defer { _cancelState.lock.unlock() }
		return _cancelState.flag
	}
	
	nonisolated static func setCancelledSync(_ value: Bool) {
		_cancelState.lock.lock()
		_cancelState.flag = value
		_cancelState.lock.unlock()
	}
	
	/// Phases with their weight in the overall 0-100% progress
	enum SigningPhase: String {
		case idle = "Chờ"
		case preparing = "Chuẩn bị"
		case copying = "Sao chép"
		case modifying = "Tuỳ chỉnh"
		case signing = "Ký"
		case saving = "Lưu trữ"
		case done = "Hoàn tất"
		
		/// Start percentage for each phase (0.0 - 1.0)
		var startPercent: Double {
			switch self {
			case .idle: return 0.0
			case .preparing: return 0.0
			case .copying: return 0.02
			case .modifying: return 0.20
			case .signing: return 0.35
			case .saving: return 0.90
			case .done: return 1.0
			}
		}
		
		/// End percentage for each phase
		var endPercent: Double {
			switch self {
			case .idle: return 0.0
			case .preparing: return 0.02
			case .copying: return 0.20
			case .modifying: return 0.35
			case .signing: return 0.90
			case .saving: return 1.0
			case .done: return 1.0
			}
		}
	}
	
	func start() {
		isCapturing = true
		isCancelled = false
		LogCapture.setCancelledSync(false)
		logs = ""
		progress = 0.0
		currentPhase = .preparing
	}
	
	func cancel() {
		isCancelled = true
		LogCapture.setCancelledSync(true)
		printLog("⛔️ Đã huỷ quá trình ký.")
		stop()
	}
	
	/// Update progress within a phase (subProgress 0.0 to 1.0)
	nonisolated func updateProgress(phase: SigningPhase, subProgress: Double) {
		Task { @MainActor in
			self.currentPhase = phase
			let clamped = min(max(subProgress, 0.0), 1.0)
			let phaseRange = phase.endPercent - phase.startPercent
			self.progress = phase.startPercent + (phaseRange * clamped)
		}
	}
	
	nonisolated func setPhase(_ phase: SigningPhase) {
		Task { @MainActor in
			self.currentPhase = phase
			self.progress = phase.startPercent
		}
	}
	
	nonisolated func printLog(_ message: String) {
		Task { @MainActor in
			if !logs.isEmpty {
				logs += "\n"
			}
			logs += "[\(Date().formatted(date: .omitted, time: .standard))] \(message)"
		}
	}
	
	nonisolated func updateLastLog(_ message: String) {
		Task { @MainActor in
			var lines = logs.components(separatedBy: "\n")
			if !lines.isEmpty {
				lines.removeLast()
			}
			let newLog = "[\(Date().formatted(date: .omitted, time: .standard))] \(message)"
			lines.append(newLog)
			logs = lines.joined(separator: "\n")
		}
	}
	
	func stop() {
		isCapturing = false
		if !isCancelled {
			progress = 1.0
			currentPhase = .done
		}
	}
}
