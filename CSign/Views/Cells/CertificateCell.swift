import UIKit

// MARK: - CertificateCell
class CertificateCell: UITableViewCell {


    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemGreen
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iv.image = UIImage(systemName: "lock.shield.fill", withConfiguration: config)
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let expiryBadge: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textAlignment = .center
        l.layer.cornerRadius = 4
        l.layer.masksToBounds = true
        l.isHidden = true
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(expiryBadge)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: expiryBadge.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            expiryBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            expiryBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            expiryBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            expiryBadge.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    func configure(with cert: Certificate) {
        titleLabel.text = cert.commonName

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var subtitle = cert.organization ?? ""
        if !subtitle.isEmpty { subtitle += " · " }
        subtitle += "Expires: \(dateFormatter.string(from: cert.expirationDate))"
        subtitleLabel.text = subtitle

        if cert.isExpired {
            iconImageView.tintColor = .systemRed
            expiryBadge.isHidden = false
            expiryBadge.text = " EXPIRED "
            expiryBadge.textColor = .white
            expiryBadge.backgroundColor = .systemRed
        } else if cert.daysUntilExpiration < 30 {
            iconImageView.tintColor = .systemOrange
            expiryBadge.isHidden = false
            expiryBadge.text = " \(cert.daysUntilExpiration)d "
            expiryBadge.textColor = .white
            expiryBadge.backgroundColor = .systemOrange
        } else {
            iconImageView.tintColor = .systemGreen
            expiryBadge.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        expiryBadge.isHidden = true
        iconImageView.tintColor = .systemGreen
    }
}
