import UIKit

// MARK: - Selected Place Cell (for success screen list)
class SelectedPlaceCell: UITableViewCell {
    private let placeImageView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let checkboxView = UIView()
    private let checkmarkIcon = UIImageView()
    private let savedLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .white
        
        placeImageView.contentMode = .scaleAspectFill
        placeImageView.clipsToBounds = true
        placeImageView.layer.cornerRadius = 8
        placeImageView.backgroundColor = .systemGray6
        placeImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeImageView)
        
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .black
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .systemGray
        addressLabel.numberOfLines = 2
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addressLabel)
        
        savedLabel.text = "saved by you"
        savedLabel.font = .systemFont(ofSize: 12)
        savedLabel.textColor = .systemGray2
        savedLabel.isHidden = true
        savedLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(savedLabel)
        
        checkboxView.layer.borderWidth = 2
        checkboxView.layer.borderColor = UIColor.systemGray4.cgColor
        checkboxView.layer.cornerRadius = 12
        checkboxView.backgroundColor = .white
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkboxView)
        
        checkmarkIcon.image = UIImage(systemName: "checkmark")
        checkmarkIcon.tintColor = .white
        checkmarkIcon.contentMode = .scaleAspectFit
        checkmarkIcon.isHidden = true
        checkmarkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkboxView.addSubview(checkmarkIcon)
        
        NSLayoutConstraint.activate([
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 60),
            placeImageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            savedLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 4),
            savedLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            
            checkboxView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            checkboxView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxView.widthAnchor.constraint(equalToConstant: 24),
            checkboxView.heightAnchor.constraint(equalToConstant: 24),
            
            checkmarkIcon.centerXAnchor.constraint(equalTo: checkboxView.centerXAnchor),
            checkmarkIcon.centerYAnchor.constraint(equalTo: checkboxView.centerYAnchor),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 16),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // Configure with main place (from Instagram)
    func configure(with place: PlaceResponse, isMainPlace: Bool, isSaved: Bool) {
        nameLabel.text = place.name
        addressLabel.text = place.address ?? "\(place.district ?? ""), Hong Kong"
        
        // Always show filled checkbox (selected)
        checkboxView.backgroundColor = .black
        checkboxView.layer.borderColor = UIColor.black.cgColor
        checkmarkIcon.isHidden = false
        
        // Show "saved by you" if already on radar
        savedLabel.isHidden = !isSaved
        
        // Load image
        if let photoURLString = place.photo_url, let photoURL = URL(string: photoURLString) {
            URLSession.shared.dataTask(with: photoURL) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.placeImageView.image = image
                }
            }.resume()
        }
    }
    
    // Configure with search result
    func configure(with selectablePlace: SelectablePlace) {
        let result = selectablePlace.googlePlace
        nameLabel.text = result.name
        addressLabel.text = result.address
        
        // Always show filled checkbox (selected)
        checkboxView.backgroundColor = .black
        checkboxView.layer.borderColor = UIColor.black.cgColor
        checkmarkIcon.isHidden = false
        
        // Show "saved by you" if already on radar
        savedLabel.isHidden = !selectablePlace.isSavedOnRadar
        
        // Load image
        if let photoURLString = result.photoUrl, let photoURL = URL(string: photoURLString) {
            URLSession.shared.dataTask(with: photoURL) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.placeImageView.image = image
                }
            }.resume()
        }
    }
}
