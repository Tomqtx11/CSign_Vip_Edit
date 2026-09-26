import UIKit

class CertificateListViewController: UIViewController {

    // MARK: - Properties
    private var certificates: [Certificate] = []
    private var profiles: [ProvisionProfile] = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(CertificateCell.self, forCellReuseIdentifier: CertificateCell.reuseIdentifier)
        tv.register(ProfileCell.self, forCellReuseIdentifier: ProfileCell.reuseIdentifier)
        tv.refreshControl = refreshControl
        return tv
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        return rc
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let v = EmptyStateView(
            iconName: "lock.shield",
            title: "No Certificates",
            detail: "Import P12 certificates and provisioning profiles to start signing apps."
        )
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Certificates"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true

        // Add button
        let addMenu = UIMenu(title: "Import", children: [
            UIAction(title: "Import Certificate (.p12)", image: UIImage(systemName: "lock.doc")) { [weak self] _ in
                self?.importCertificate()
            },
            UIAction(title: "Import Profile (.mobileprovision)", image: UIImage(systemName: "doc.badge.gearshape")) { [weak self] _ in
                self?.importProfile()
            }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, menu: addMenu)

        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Data

    private func loadData() {
        certificates = StorageManager.shared.loadCertificates()
        profiles = StorageManager.shared.loadProfiles()
        tableView.reloadData()
        emptyStateView.isHidden = !(certificates.isEmpty && profiles.isEmpty)
        refreshControl.endRefreshing()
    }

    @objc private func refreshData() {
        loadData()
    }

    // MARK: - Import

    private func importCertificate() {
        let types = ["com.rsa.pkcs-12", "public.data"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        picker.view.tag = 100 // tag to distinguish cert vs profile
        present(picker, animated: true)
    }

    private func importProfile() {
        let types = ["com.apple.mobileprovision", "public.data"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        picker.view.tag = 200
        present(picker, animated: true)
    }

    private func handleP12Import(url: URL) {
        let alert = UIAlertController(title: "Certificate Password", message: "Enter the password for this P12 certificate", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Password"
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            guard let password = alert.textFields?.first?.text else { return }
            self?.processCertificateImport(url: url, password: password)
        })
        present(alert, animated: true)
    }

    private func processCertificateImport(url: URL, password: String) {
        // Copy to certificates directory
        let destPath = StorageManager.shared.certificatesDirectory + "/" + url.lastPathComponent
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
        } catch {
            showAlert(title: "Error", message: "Failed to copy certificate: \(error.localizedDescription)")
            return
        }

        // Parse certificate
        guard let cert = CertificateParser.parsePKCS12(at: destPath, password: password) else {
            showAlert(title: "Error", message: "Invalid P12 file or wrong password")
            try? FileManager.default.removeItem(atPath: destPath)
            return
        }

        // Save password to keychain for later use
        let passwordKey = "csign.cert.\(cert.id)"
        KeychainHelper.save(password, forKey: passwordKey)

        certificates.append(cert)
        StorageManager.shared.saveCertificates(certificates)
        tableView.reloadData()
        emptyStateView.isHidden = true

        showAlert(title: "Success", message: "Certificate '\(cert.commonName)' imported successfully")
    }

    private func processProfileImport(url: URL) {
        let destPath = StorageManager.shared.provisionsDirectory + "/" + url.lastPathComponent
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
        } catch {
            showAlert(title: "Error", message: "Failed to copy profile: \(error.localizedDescription)")
            return
        }

        guard let profile = CertificateParser.parseProvisioningProfile(at: destPath) else {
            showAlert(title: "Error", message: "Invalid provisioning profile")
            try? FileManager.default.removeItem(atPath: destPath)
            return
        }

        profiles.append(profile)
        StorageManager.shared.saveProfiles(profiles)
        tableView.reloadData()
        emptyStateView.isHidden = true

        showAlert(title: "Success", message: "Profile '\(profile.name)' imported successfully")
    }

    private func deleteCertificate(at index: Int) {
        let cert = certificates[index]
        try? FileManager.default.removeItem(atPath: cert.p12FilePath)
        certificates.remove(at: index)
        StorageManager.shared.saveCertificates(certificates)
        tableView.reloadData()
        emptyStateView.isHidden = !(certificates.isEmpty && profiles.isEmpty)
    }

    private func deleteProfile(at index: Int) {
        let profile = profiles[index]
        try? FileManager.default.removeItem(atPath: profile.filePath)
        profiles.remove(at: index)
        StorageManager.shared.saveProfiles(profiles)
        tableView.reloadData()
        emptyStateView.isHidden = !(certificates.isEmpty && profiles.isEmpty)
    }
}

// MARK: - UITableViewDataSource
extension CertificateListViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return certificates.isEmpty ? nil : "Certificates (\(certificates.count))"
        case 1: return profiles.isEmpty ? nil : "Provisioning Profiles (\(profiles.count))"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return certificates.count
        case 1: return profiles.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: CertificateCell.reuseIdentifier, for: indexPath) as! CertificateCell
            cell.configure(with: certificates[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.reuseIdentifier, for: indexPath) as! ProfileCell
            cell.configure(with: profiles[indexPath.row])
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension CertificateListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            let detailVC = CertificateDetailViewController(certificate: certificates[indexPath.row])
            detailVC.onDelete = { [weak self] in
                self?.deleteCertificate(at: indexPath.row)
            }
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete this item?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                if indexPath.section == 0 {
                    self?.deleteCertificate(at: indexPath.row)
                } else {
                    self?.deleteProfile(at: indexPath.row)
                }
                completion(true)
            })
            self?.present(alert, animated: true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - UIDocumentPickerDelegate
extension CertificateListViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        let ext = url.pathExtension.lowercased()
        if ext == "p12" || ext == "pfx" || controller.view.tag == 100 {
            handleP12Import(url: url)
        } else if ext == "mobileprovision" || controller.view.tag == 200 {
            processProfileImport(url: url)
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
