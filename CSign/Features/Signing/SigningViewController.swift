import UIKit

class SigningViewController: UIViewController {
    
    var ipaFile: IPAFile?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Sign App"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        let startButton = UIBarButtonItem(title: "Start Signing", style: .done, target: self, action: #selector(startTapped))
        startButton.tintColor = .systemBlue
        navigationItem.rightBarButtonItem = startButton
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func startTapped() {
        guard let ipa = ipaFile else { return }
        
        let certs = StorageManager.shared.loadCertificates()
        guard let cert = certs.first else {
            let alert = UIAlertController(title: "Error", message: "Please import a certificate in the Certs tab first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let profiles = StorageManager.shared.loadProfiles()
        let profile = profiles.first
        
        let pwd = KeychainHelper.load(forKey: "csign.cert.\(cert.id)") ?? ""
        let options = IPASigner.SigningOptions(
            certificate: cert,
            certificatePassword: pwd,
            profile: profile,
            newBundleId: ipa.bundleIdentifier,
            newDisplayName: ipa.bundleName,
            removePlugins: false,
            removeSupportedDevices: false,
            removeURLSchemes: false,
            fileSharingEnabled: true
        )
        
        let progressVC = SigningProgressViewController()
        progressVC.ipaFile = ipa
        progressVC.options = options
        navigationController?.pushViewController(progressVC, animated: true)
    }
}

extension SigningViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3
        case 1: return 1
        case 2: return 1
        case 3: return 4
        case 4: return 1
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "App Info"
        case 1: return "Certificate"
        case 2: return "Provisioning Profile"
        case 3: return "Options"
        case 4: return "Advanced"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = ipaFile?.bundleName ?? "Unknown"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Bundle ID"
                cell.detailTextLabel?.text = ipaFile?.bundleIdentifier ?? "Unknown"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = ipaFile?.version ?? "1.0"
            }
        }
        else if indexPath.section == 1 {
            cell.textLabel?.text = "Select Certificate"
            cell.accessoryType = .disclosureIndicator
        }
        else if indexPath.section == 2 {
            cell.textLabel?.text = "Select Profile"
            cell.accessoryType = .disclosureIndicator
        }
        else if indexPath.section == 3 {
            let toggle = UISwitch()
            cell.accessoryView = toggle
            switch indexPath.row {
            case 0: cell.textLabel?.text = "Remove App Extensions"
            case 1: cell.textLabel?.text = "Remove Supported Devices"
            case 2: cell.textLabel?.text = "Enable File Sharing"; toggle.isOn = true
            case 3: cell.textLabel?.text = "Remove URL Schemes"
            default: break
            }
        } else if indexPath.section == 4 {
            cell.textLabel?.text = "Inject Dylib"
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
}
