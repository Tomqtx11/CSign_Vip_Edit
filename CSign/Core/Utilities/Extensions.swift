import UIKit

extension UIViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func showError(_ error: Error) {
        showAlert(title: "Error", message: error.localizedDescription)
    }
    
    func showSuccess(_ message: String) {
        showAlert(title: "Success", message: message)
    }
}

extension UIView {
    func addSubviewWithConstraints(_ view: UIView, top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: top),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottom),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailing)
        ])
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension Int64 {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

extension Date {
    var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

extension UIColor {
    static let csignPrimary = UIColor.systemBlue
    static let csignBackground = UIColor.systemBackground
    static let csignSecondaryBackground = UIColor.secondarySystemBackground
    static let csignText = UIColor.label
    static let csignSecondaryText = UIColor.secondaryLabel
}

extension UITableViewCell {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}
