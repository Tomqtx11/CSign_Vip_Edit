import UIKit

class CertificateDetailViewController: UIViewController {

    // MARK: - Properties
    private let certificate: Certificate
    var onDelete: (() -> Void)?

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()

    private struct Section {
        let title: String
        let rows: [(key: String, value: String)]
    }

    private var sections: [Section] = []

    // MARK: - Init

    init(certificate: Certificate) {
        self.certificate = certificate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        buildSections()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Certificate Detail"
        view.backgroundColor = .systemBackground

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func buildSections() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        // Subject
        var subjectRows: [(String, String)] = [
            ("Common Name", certificate.commonName),
        ]
        if let org = certificate.organization, !org.isEmpty {
            subjectRows.append(("Organization", org))
        }
        if let ou = certificate.organizationUnit, !ou.isEmpty {
            subjectRows.append(("Org Unit", ou))
        }
        sections.append(Section(title: "Subject", rows: subjectRows))

        // Validity
        let daysLeft = certificate.daysUntilExpiration
        let expiryStatus: String
        if certificate.isExpired {
            expiryStatus = "⛔️ Expired"
        } else if daysLeft < 30 {
            expiryStatus = "⚠️ \(daysLeft) days remaining"
        } else {
            expiryStatus = "✅ \(daysLeft) days remaining"
        }

        sections.append(Section(title: "Validity", rows: [
            ("Created", dateFormatter.string(from: certificate.creationDate)),
            ("Expires", dateFormatter.string(from: certificate.expirationDate)),
            ("Status", expiryStatus),
        ]))

        // Serial Number
        if !certificate.serialNumber.isEmpty {
            sections.append(Section(title: "Details", rows: [
                ("Serial Number", certificate.serialNumber),
            ]))
        }

        // File
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: certificate.p12FilePath)[.size] as? Int64) ?? 0
        let sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        sections.append(Section(title: "File", rows: [
            ("Path", certificate.p12FilePath),
            ("Size", sizeStr),
            ("Imported", dateFormatter.string(from: certificate.importDate)),
        ]))

        // Delete
        sections.append(Section(title: "", rows: [
            ("__DELETE__", "Delete Certificate"),
        ]))

        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension CertificateDetailViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let title = sections[section].title
        return title.isEmpty ? nil : title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        if row.key == "__DELETE__" {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = row.value
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            return cell
        }

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = row.key
        cell.textLabel?.font = .systemFont(ofSize: 15)
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.font = .systemFont(ofSize: 15)
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none

        // Color code expiry status
        if row.key == "Status" {
            if row.value.contains("Expired") {
                cell.detailTextLabel?.textColor = .systemRed
            } else if row.value.contains("⚠️") {
                cell.detailTextLabel?.textColor = .systemOrange
            } else {
                cell.detailTextLabel?.textColor = .systemGreen
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension CertificateDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].rows[indexPath.row]
        if row.key == "__DELETE__" {
            let alert = UIAlertController(
                title: "Delete Certificate",
                message: "Are you sure you want to delete '\(certificate.commonName)'? This action cannot be undone.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                self?.onDelete?()
                self?.navigationController?.popViewController(animated: true)
            })
            present(alert, animated: true)
        } else if row.key == "Serial Number" || row.key == "Path" {
            UIPasteboard.general.string = row.value
            showAlert(title: "Copied", message: "\(row.key) copied to clipboard")
        }
    }
}
