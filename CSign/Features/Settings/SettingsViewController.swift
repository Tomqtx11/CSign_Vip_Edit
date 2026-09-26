import UIKit

class SettingsViewController: UITableViewController {
    
    private let sections = [
        "Signing Defaults",
        "Installation",
        "Storage",
        "About"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView = UITableView(frame: tableView.frame, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return 2
        case 2: return 3
        case 3: return 4
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "Default Certificate"
            cell.detailTextLabel?.text = "None"
            cell.accessoryType = .disclosureIndicator
        case (0, 1):
            cell.textLabel?.text = "Default Provisioning Profile"
            cell.detailTextLabel?.text = "None"
            cell.accessoryType = .disclosureIndicator
        case (1, 0):
            cell.textLabel?.text = "Install Server Port"
            cell.detailTextLabel?.text = "8765"
            cell.accessoryType = .disclosureIndicator
        case (1, 1):
            cell.textLabel?.text = "Use HTTPS"
            let switchView = UISwitch()
            cell.accessoryView = switchView
        case (2, 0):
            cell.textLabel?.text = "Cache Size"
            cell.detailTextLabel?.text = "0 MB"
        case (2, 1):
            cell.textLabel?.text = "Clear Cache"
            cell.textLabel?.textColor = .systemRed
        case (2, 2):
            cell.textLabel?.text = "Clear All Data"
            cell.textLabel?.textColor = .systemRed
        case (3, 0):
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = "1.0"
        case (3, 1):
            cell.textLabel?.text = "Build"
            cell.detailTextLabel?.text = "1"
        case (3, 2):
            cell.textLabel?.text = "Source Code"
            cell.accessoryType = .disclosureIndicator
        case (3, 3):
            cell.textLabel?.text = "Telegram Channel"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 2 && indexPath.row == 1 {
            let alert = UIAlertController(title: "Clear Cache", message: "Are you sure you want to clear the cache?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
                // StorageManager.shared.clearCache()
                self?.showSuccess("Cache cleared")
            })
            present(alert, animated: true)
        } else if indexPath.section == 2 && indexPath.row == 2 {
            let alert = UIAlertController(title: "Clear All Data", message: "This will delete all files and settings. Are you sure?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
                self?.showSuccess("All data cleared")
            })
            present(alert, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 3 {
            return "CSign v1.0 - Open Source IPA Signing Tool"
        }
        return nil
    }
}
