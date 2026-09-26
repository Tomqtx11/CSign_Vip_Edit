import UIKit

class AppDetailViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var headerView: UIView!
    
    // Dependencies to be injected
    var ipaFile: Any? // Should be IPAFile
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupHeader()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "App Details"
        
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
    
    private func setupHeader() {
        headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 160))
        
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 18
        iconView.clipsToBounds = true
        iconView.layer.borderWidth = 0.5
        iconView.layer.borderColor = UIColor.separator.cgColor
        iconView.image = UIImage(systemName: "app.fill")
        
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.text = "App Name"
        
        let bundleLabel = UILabel()
        bundleLabel.translatesAutoresizingMaskIntoConstraints = false
        bundleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bundleLabel.textColor = .secondaryLabel
        bundleLabel.textAlignment = .center
        bundleLabel.text = "com.example.app"
        
        headerView.addSubview(iconView)
        headerView.addSubview(nameLabel)
        headerView.addSubview(bundleLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            bundleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            bundleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            bundleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16)
        ])
        
        tableView.tableHeaderView = headerView
    }
}

extension AppDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 5 : 4
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Info" : "Actions"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        
        if indexPath.section == 0 {
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0: cell.textLabel?.text = "Bundle ID"; cell.detailTextLabel?.text = "com.example.app"
            case 1: cell.textLabel?.text = "Version"; cell.detailTextLabel?.text = "1.0"
            case 2: cell.textLabel?.text = "Min iOS"; cell.detailTextLabel?.text = "14.0"
            case 3: cell.textLabel?.text = "File Size"; cell.detailTextLabel?.text = "10 MB"
            case 4: cell.textLabel?.text = "Import Date"; cell.detailTextLabel?.text = "Today"
            default: break
            }
        } else {
            cell.detailTextLabel?.text = nil
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Sign App"
                cell.textLabel?.textColor = .systemBlue
            case 1:
                cell.textLabel?.text = "View Contents"
                cell.textLabel?.textColor = .label
            case 2:
                cell.textLabel?.text = "Share IPA"
                cell.textLabel?.textColor = .label
            case 3:
                cell.textLabel?.text = "Delete"
                cell.textLabel?.textColor = .systemRed
            default: break
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle actions...
    }
}
