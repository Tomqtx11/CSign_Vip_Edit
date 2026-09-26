import UIKit
import UniformTypeIdentifiers
import ZIPFoundation

class CertificateListViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var emptyStateView: EmptyStateView!
    
    private var certificates: [Certificate] = []
    private var profiles: [ProvisionProfile] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        title = "Certificates"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let importMenu = UIMenu(title: "", children: [
            UIAction(title: "Import P12", image: UIImage(systemName: "key")) { [weak self] _ in self?.openDocumentPicker(for: "p12") },
            UIAction(title: "Import Profile", image: UIImage(systemName: "doc.badge.gearshape")) { [weak self] _ in self?.openDocumentPicker(for: "mobileprovision") },
            UIAction(title: "Import ZIP", image: UIImage(systemName: "doc.zipper")) { [weak self] _ in self?.openDocumentPicker(for: "zip") }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", image: UIImage(systemName: "plus"), primaryAction: nil, menu: importMenu)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CertificateCell.self, forCellReuseIdentifier: "CertificateCell")
        tableView.register(ProfileCell.self, forCellReuseIdentifier: "ProfileCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        emptyStateView = EmptyStateView(iconName: "lock.shield", title: "No Certificates", detail: "Import P12, Provisioning Profiles or a ZIP file")
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadData() {
        certificates = StorageManager.shared.loadCertificates()
        profiles = StorageManager.shared.loadProfiles()
        tableView.reloadData()
        emptyStateView.isHidden = !(certificates.isEmpty && profiles.isEmpty)
    }
    
    private func openDocumentPicker(for type: String) {
        var types: [String] = []
        if type == "p12" { types = ["com.rsa.pkcs-12"] }
        else if type == "mobileprovision" { types = ["com.apple.mobileprovision"] }
        else if type == "zip" { types = ["public.zip-archive"] }
        
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func handleP12Import(url: URL) {
        let alert = UIAlertController(title: "Import Certificate", message: "Enter password for \(url.lastPathComponent)", preferredStyle: .alert)
        alert.addTextField { tf in tf.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            let pwd = alert.textFields?.first?.text ?? ""
            self?.processP12Import(url: url, password: pwd)
        })
        present(alert, animated: true)
    }
    
    private func processP12Import(url: URL, password: String) {
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
        
        guard let cert = CertificateParser.parsePKCS12(at: destPath, password: password) else {
            showAlert(title: "Error", message: "Invalid P12 file or wrong password")
            try? FileManager.default.removeItem(atPath: destPath)
            return
        }
        
        let passwordKey = "csign.cert.\(cert.id)"
        KeychainHelper.save(password, forKey: passwordKey)
        
        certificates.append(cert)
        StorageManager.shared.saveCertificates(certificates)
        loadData()
        showAlert(title: "Success", message: "Certificate imported successfully")
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
        loadData()
        showAlert(title: "Success", message: "Profile imported successfully")
    }
    
    private func handleZipImport(url: URL) {
        let alert = UIAlertController(title: "Import ZIP", message: "Enter password for the certificates in this ZIP", preferredStyle: .alert)
        alert.addTextField { tf in tf.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            let pwd = alert.textFields?.first?.text ?? ""
            self?.processZipImport(url: url, password: pwd)
        })
        present(alert, animated: true)
    }
    
    private func processZipImport(url: URL, password: String) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: url, to: tempDir)
            
            var foundCerts = 0
            var foundProfiles = 0
            
            if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "p12" {
                        processP12Import(url: fileURL, password: password)
                        foundCerts += 1
                    } else if fileURL.pathExtension.lowercased() == "mobileprovision" {
                        processProfileImport(url: fileURL)
                        foundProfiles += 1
                    }
                }
            }
            
            showAlert(title: "ZIP Import Completed", message: "Found \(foundCerts) certs and \(foundProfiles) profiles.")
            
        } catch {
            showAlert(title: "Error", message: "Failed to extract ZIP: \(error.localizedDescription)")
        }
    }
    
    private func deleteCertificate(at index: Int) {
        let cert = certificates[index]
        try? FileManager.default.removeItem(atPath: cert.p12FilePath)
        certificates.remove(at: index)
        StorageManager.shared.saveCertificates(certificates)
        loadData()
    }
    
    private func deleteProfile(at index: Int) {
        let profile = profiles[index]
        try? FileManager.default.removeItem(atPath: profile.filePath)
        profiles.remove(at: index)
        StorageManager.shared.saveProfiles(profiles)
        loadData()
    }
}

extension CertificateListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { return 2 }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return certificates.isEmpty ? nil : "Certificates (\(certificates.count))" }
        return profiles.isEmpty ? nil : "Provisioning Profiles (\(profiles.count))"
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? certificates.count : profiles.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
            cell.configure(with: certificates[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileCell
            cell.configure(with: profiles[indexPath.row])
            return cell
        }
    }
}

extension CertificateListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let detailVC = CertificateDetailViewController(certificate: certificates[indexPath.row])
            detailVC.onDelete = { [weak self] in self?.deleteCertificate(at: indexPath.row) }
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            if indexPath.section == 0 { self?.deleteCertificate(at: indexPath.row) }
            else { self?.deleteProfile(at: indexPath.row) }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 72 }
}

extension CertificateListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        if ext == "zip" {
            handleZipImport(url: url)
        } else if ext == "p12" {
            handleP12Import(url: url)
        } else if ext == "mobileprovision" {
            processProfileImport(url: url)
        }
    }
}

class KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [ kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecValueData as String: data ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [ kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
