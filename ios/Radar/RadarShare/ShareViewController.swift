import UIKit
import Social
import UniformTypeIdentifiers
import Security

// MARK: - Keychain Helper for Share Extension
private struct ShareKeychainHelper {
    static let accessGroup = "group.com.hongkeilung.radar"
    
    static func readAccessToken() -> String? {
        // Try with App Groups first
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        // Fallback: Try without App Groups
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true
        ]
        
        result = nil
        status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        return nil
    }
}

// MARK: - API Config
private struct ShareAPIConfig {
    static let baseURL = "https://radar-production-0277.up.railway.app"
}

// MARK: - Response Models
struct PlaceResponse: Codable {
    let id: Int
    let name: String
    let address: String?
    let district: String?
    let lat: Double
    let lng: Double
    let category: String
    let emoji: String
    let photo_url: String?
    let rating: Double?
    let is_visited: Bool
    let is_favorite: Bool
    let tags: [String]?
    let source_url: String?
    let created_at: String
    let place_id: String?
}

struct GooglePlaceResult: Codable {
    let place_id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let rating: Double?
    let photoUrl: String?
}

struct GoogleSearchResponse: Codable {
    let results: [GooglePlaceResult]
}

struct ErrorResponse: Codable {
    let detail: String
}

struct PlacesListResponse: Codable {
    let places: [PlaceResponse]
}

// MARK: - Selectable Place Model
struct SelectablePlace {
    let googlePlace: GooglePlaceResult
    var isSelected: Bool
    var isSavedOnRadar: Bool
}

// MARK: - Share View Controller
class ShareViewController: UIViewController {
    
    private var sharedURL: String?
    private var savedPlace: PlaceResponse?
    private var isMainPlaceSelected: Bool = true // Main place is selected by default
    private var searchResults: [SelectablePlace] = []
    private var allSavedPlaces: [PlaceResponse] = []
    
    // UI Elements - Loading State
    private let loadingContainerView = UIView()
    private let loadingEmojiLabel = UILabel()
    private let loadingStatusLabel = UILabel()
    
    // UI Elements - Success State (Corner-style)
    private let successContainerView = UIView()
    private var successBottomConstraint: NSLayoutConstraint!
    private let headerLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let placeCardView = UIView()
    private let placeImageView = UIImageView()
    private let placeNameLabel = UILabel()
    private let placeAddressLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    private let savedLabel = UILabel()
    private let searchTextField = UITextField()
    private let selectedPlacesTableView = UITableView()
    private let addButton = UIButton(type: .system)
    
    // UI Elements - Search Mode
    private let searchContainerView = UIView()
    private let searchBarView = UIView()
    private let searchIconImageView = UIImageView()
    private let searchInputField = UITextField()
    private let searchCloseButton = UIButton(type: .system)
    private let searchResultsTableView = UITableView()
    
    // UI Elements - Error State
    private let errorContainerView = UIView()
    private let errorIconLabel = UILabel()
    private let errorMessageLabel = UILabel()
    private let errorCloseButton = UIButton(type: .system)
    
    private enum State {
        case loading
        case success(PlaceResponse)
        case searching
        case error(String)
    }
    
    private var currentState: State = .loading {
        didSet {
            updateUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedURL()
        
        // Keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        setupLoadingUI()
        setupSuccessUI()
        setupSearchUI()
        setupErrorUI()
        
        // Show loading by default
        loadingContainerView.isHidden = false
        successContainerView.isHidden = true
        searchContainerView.isHidden = true
        errorContainerView.isHidden = true
    }
    
    private func setupLoadingUI() {
        // Container - White background
        loadingContainerView.backgroundColor = .white
        loadingContainerView.layer.cornerRadius = 24
        loadingContainerView.layer.shadowColor = UIColor.black.cgColor
        loadingContainerView.layer.shadowOpacity = 0.1
        loadingContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        loadingContainerView.layer.shadowRadius = 12
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingContainerView)
        
        // Emoji
        loadingEmojiLabel.text = "🌍"
        loadingEmojiLabel.font = .systemFont(ofSize: 60)
        loadingEmojiLabel.textAlignment = .center
        loadingEmojiLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(loadingEmojiLabel)
        
        // Status label - Black text
        loadingStatusLabel.text = "finding your next hangout spot..."
        loadingStatusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        loadingStatusLabel.textAlignment = .center
        loadingStatusLabel.textColor = .black
        loadingStatusLabel.numberOfLines = 0
        loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(loadingStatusLabel)
        
        NSLayoutConstraint.activate([
            loadingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            loadingContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            loadingEmojiLabel.topAnchor.constraint(equalTo: loadingContainerView.topAnchor, constant: 40),
            loadingEmojiLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            
            loadingStatusLabel.topAnchor.constraint(equalTo: loadingEmojiLabel.bottomAnchor, constant: 20),
            loadingStatusLabel.leadingAnchor.constraint(equalTo: loadingContainerView.leadingAnchor, constant: 24),
            loadingStatusLabel.trailingAnchor.constraint(equalTo: loadingContainerView.trailingAnchor, constant: -24),
            loadingStatusLabel.bottomAnchor.constraint(equalTo: loadingContainerView.bottomAnchor, constant: -40)
        ])
    }
    
    private func setupSuccessUI() {
        // Container - White background, bottom sheet style
        successContainerView.backgroundColor = .white
        successContainerView.layer.cornerRadius = 24
        successContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        successContainerView.layer.shadowColor = UIColor.black.cgColor
        successContainerView.layer.shadowOpacity = 0.1
        successContainerView.layer.shadowOffset = CGSize(width: 0, height: -4)
        successContainerView.layer.shadowRadius = 12
        successContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(successContainerView)
        
        // Header label
        headerLabel.text = "add to radar"
        headerLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = .black
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(headerLabel)
        
        // Close button (X)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.black, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .light)
        closeButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(closeButton)
        
        // Place card
        placeCardView.backgroundColor = .white
        placeCardView.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(placeCardView)
        
        // Place image (Google photo)
        placeImageView.contentMode = .scaleAspectFill
        placeImageView.clipsToBounds = true
        placeImageView.layer.cornerRadius = 8
        placeImageView.backgroundColor = .systemGray6
        placeImageView.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeImageView)
        
        // Place name
        placeNameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        placeNameLabel.textColor = .black
        placeNameLabel.numberOfLines = 2
        placeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeNameLabel)
        
        // Place address
        placeAddressLabel.font = .systemFont(ofSize: 14)
        placeAddressLabel.textColor = .systemGray
        placeAddressLabel.numberOfLines = 2
        placeAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(placeAddressLabel)
        
        // Checkmark (tappable)
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = .black
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.isUserInteractionEnabled = true
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(checkmarkImageView)
        
        let checkmarkTap = UITapGestureRecognizer(target: self, action: #selector(toggleMainPlaceSelection))
        checkmarkImageView.addGestureRecognizer(checkmarkTap)
        
        // "saved by you" label (no emoji)
        savedLabel.text = "saved by you"
        savedLabel.font = .systemFont(ofSize: 12)
        savedLabel.textColor = .systemGray2
        savedLabel.isHidden = true // Hidden by default, shown if place is already saved
        savedLabel.translatesAutoresizingMaskIntoConstraints = false
        placeCardView.addSubview(savedLabel)
        
        // Search text field - White background with black text
        searchTextField.font = .systemFont(ofSize: 16)
        searchTextField.textColor = .black
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "find a different place",
            attributes: [.foregroundColor: UIColor.black]
        )
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = .white
        searchTextField.layer.cornerRadius = 12
        searchTextField.layer.borderWidth = 1
        searchTextField.layer.borderColor = UIColor.systemGray5.cgColor
        searchTextField.delegate = self
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(searchTextField)
        
        // Add magnifying glass icon
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = .systemGray
        searchIcon.contentMode = .scaleAspectFit
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.addSubview(searchIcon)
        
        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchTextField.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchTextField.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        searchTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 48))
        searchTextField.leftViewMode = .always
        
        // Selected places table view (shows all selected places)
        selectedPlacesTableView.backgroundColor = .white
        selectedPlacesTableView.separatorStyle = .none
        selectedPlacesTableView.delegate = self
        selectedPlacesTableView.dataSource = self
        selectedPlacesTableView.register(SelectedPlaceCell.self, forCellReuseIdentifier: "SelectedPlaceCell")
        selectedPlacesTableView.isScrollEnabled = true
        selectedPlacesTableView.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(selectedPlacesTableView)
        
        // Add button
        addButton.setTitle("add 1 place", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        addButton.backgroundColor = .black
        addButton.layer.cornerRadius = 28
        addButton.addTarget(self, action: #selector(addPlaces), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        successContainerView.addSubview(addButton)
        
        successBottomConstraint = successContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            successContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            successContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            successBottomConstraint,
            
            headerLabel.topAnchor.constraint(equalTo: successContainerView.topAnchor, constant: 24),
            headerLabel.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            
            closeButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            placeCardView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 24),
            placeCardView.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            placeCardView.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            placeCardView.heightAnchor.constraint(equalToConstant: 0), // Hidden, using table view instead
            
            placeImageView.leadingAnchor.constraint(equalTo: placeCardView.leadingAnchor),
            placeImageView.centerYAnchor.constraint(equalTo: placeCardView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 60),
            placeImageView.heightAnchor.constraint(equalToConstant: 60),
            
            placeNameLabel.topAnchor.constraint(equalTo: placeCardView.topAnchor, constant: 8),
            placeNameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            placeNameLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            placeAddressLabel.topAnchor.constraint(equalTo: placeNameLabel.bottomAnchor, constant: 4),
            placeAddressLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            placeAddressLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            checkmarkImageView.trailingAnchor.constraint(equalTo: placeCardView.trailingAnchor),
            checkmarkImageView.topAnchor.constraint(equalTo: placeCardView.topAnchor, constant: 8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            
            savedLabel.topAnchor.constraint(equalTo: placeAddressLabel.bottomAnchor, constant: 4),
            savedLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            
            selectedPlacesTableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 24),
            selectedPlacesTableView.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            selectedPlacesTableView.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            selectedPlacesTableView.heightAnchor.constraint(equalToConstant: 200), // Will be dynamic
            
            searchTextField.topAnchor.constraint(equalTo: selectedPlacesTableView.bottomAnchor, constant: 24),
            searchTextField.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            searchTextField.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            searchTextField.heightAnchor.constraint(equalToConstant: 48),
            
            addButton.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 24),
            addButton.leadingAnchor.constraint(equalTo: successContainerView.leadingAnchor, constant: 24),
            addButton.trailingAnchor.constraint(equalTo: successContainerView.trailingAnchor, constant: -24),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            addButton.bottomAnchor.constraint(equalTo: successContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupSearchUI() {
        // Full screen search container
        searchContainerView.backgroundColor = .white
        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainerView)
        
        // Search bar at top
        searchBarView.backgroundColor = .black
        searchBarView.layer.cornerRadius = 24
        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchBarView)
        
        // Search icon
        searchIconImageView.image = UIImage(systemName: "magnifyingglass")
        searchIconImageView.tintColor = .white
        searchIconImageView.contentMode = .scaleAspectFit
        searchIconImageView.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.addSubview(searchIconImageView)
        
        // Search input field
        searchInputField.font = .systemFont(ofSize: 18)
        searchInputField.textColor = .white
        searchInputField.attributedPlaceholder = NSAttributedString(
            string: "search places",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        searchInputField.borderStyle = .none
        searchInputField.backgroundColor = .clear
        searchInputField.returnKeyType = .search
        searchInputField.autocorrectionType = .no
        searchInputField.delegate = self
        searchInputField.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        searchInputField.translatesAutoresizingMaskIntoConstraints = false
        searchBarView.addSubview(searchInputField)
        
        // Close button
        searchCloseButton.setTitle("✕", for: .normal)
        searchCloseButton.setTitleColor(.black, for: .normal)
        searchCloseButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .light)
        searchCloseButton.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
        searchCloseButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchCloseButton)
        
        // Results table
        searchResultsTableView.backgroundColor = .white
        searchResultsTableView.separatorStyle = .none
        searchResultsTableView.delegate = self
        searchResultsTableView.dataSource = self
        searchResultsTableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        searchResultsTableView.translatesAutoresizingMaskIntoConstraints = false
        searchContainerView.addSubview(searchResultsTableView)
        
        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            searchContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            searchBarView.topAnchor.constraint(equalTo: searchContainerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchBarView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 24),
            searchBarView.trailingAnchor.constraint(equalTo: searchCloseButton.leadingAnchor, constant: -12),
            searchBarView.heightAnchor.constraint(equalToConstant: 48),
            
            searchIconImageView.leadingAnchor.constraint(equalTo: searchBarView.leadingAnchor, constant: 16),
            searchIconImageView.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            searchIconImageView.widthAnchor.constraint(equalToConstant: 20),
            searchIconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            searchInputField.leadingAnchor.constraint(equalTo: searchIconImageView.trailingAnchor, constant: 12),
            searchInputField.trailingAnchor.constraint(equalTo: searchBarView.trailingAnchor, constant: -16),
            searchInputField.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            
            searchCloseButton.centerYAnchor.constraint(equalTo: searchBarView.centerYAnchor),
            searchCloseButton.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -24),
            searchCloseButton.widthAnchor.constraint(equalToConstant: 32),
            searchCloseButton.heightAnchor.constraint(equalToConstant: 32),
            
            searchResultsTableView.topAnchor.constraint(equalTo: searchBarView.bottomAnchor, constant: 16),
            searchResultsTableView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor),
            searchResultsTableView.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor),
            searchResultsTableView.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor)
        ])
    }
    
    private func setupErrorUI() {
        // Container - White background
        errorContainerView.backgroundColor = .white
        errorContainerView.layer.cornerRadius = 24
        errorContainerView.layer.shadowColor = UIColor.black.cgColor
        errorContainerView.layer.shadowOpacity = 0.1
        errorContainerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        errorContainerView.layer.shadowRadius = 12
        errorContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorContainerView)
        
        // Error icon
        errorIconLabel.text = "⚠️"
        errorIconLabel.font = .systemFont(ofSize: 60)
        errorIconLabel.textAlignment = .center
        errorIconLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorIconLabel)
        
        // Error message
        errorMessageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        errorMessageLabel.textAlignment = .center
        errorMessageLabel.textColor = .systemRed
        errorMessageLabel.numberOfLines = 0
        errorMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorMessageLabel)
        
        // Close button
        errorCloseButton.setTitle("Done", for: .normal)
        errorCloseButton.setTitleColor(.white, for: .normal)
        errorCloseButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        errorCloseButton.backgroundColor = .black
        errorCloseButton.layer.cornerRadius = 12
        errorCloseButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        errorCloseButton.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorCloseButton)
        
        NSLayoutConstraint.activate([
            errorContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            errorIconLabel.topAnchor.constraint(equalTo: errorContainerView.topAnchor, constant: 40),
            errorIconLabel.centerXAnchor.constraint(equalTo: errorContainerView.centerXAnchor),
            
            errorMessageLabel.topAnchor.constraint(equalTo: errorIconLabel.bottomAnchor, constant: 20),
            errorMessageLabel.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 24),
            errorMessageLabel.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -24),
            
            errorCloseButton.topAnchor.constraint(equalTo: errorMessageLabel.bottomAnchor, constant: 24),
            errorCloseButton.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 24),
            errorCloseButton.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -24),
            errorCloseButton.heightAnchor.constraint(equalToConstant: 50),
            errorCloseButton.bottomAnchor.constraint(equalTo: errorContainerView.bottomAnchor, constant: -32)
        ])
    }
    
    // MARK: - Extract Shared URL
    private func extractSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            currentState = .error("No content shared")
            return
        }
        
        // Check for URL
        if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self?.sharedURL = url.absoluteString
                        self?.fetchAllSavedPlaces()
                    } else {
                        self?.currentState = .error("Could not read URL")
                    }
                }
            }
        } else {
            currentState = .error("Please share an Instagram post")
        }
    }
    
    // MARK: - Fetch All Saved Places
    private func fetchAllSavedPlaces() {
        guard let token = ShareKeychainHelper.readAccessToken() else {
            currentState = .error("Please log in to Radar first")
            return
        }
        
        guard let url = URL(string: "\(ShareAPIConfig.baseURL)/places") else {
            importPlace() // Fallback to import without checking
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let placesResponse = try? JSONDecoder().decode(PlacesListResponse.self, from: data) {
                    self?.allSavedPlaces = placesResponse.places
                }
                self?.importPlace()
            }
        }.resume()
    }
    
    // MARK: - Import Place from Backend
    private func importPlace() {
        guard let urlString = sharedURL else {
            currentState = .error("No URL found")
            return
        }
        
        guard let token = ShareKeychainHelper.readAccessToken() else {
            currentState = .error("Please log in to Radar first")
            return
        }
        
        guard let url = URL(string: "\(ShareAPIConfig.baseURL)/import-url") else {
            currentState = .error("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = ["url": urlString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.currentState = .error("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.currentState = .error("No response from server")
                    return
                }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        self?.currentState = .error(errorResponse.detail)
                    } else {
                        self?.currentState = .error("Server error (\(httpResponse.statusCode))")
                    }
                    return
                }
                
                // Parse success response
                do {
                    let place = try JSONDecoder().decode(PlaceResponse.self, from: data)
                    self?.savedPlace = place
                    self?.currentState = .success(place)
                } catch {
                    self?.currentState = .error("Failed to parse response")
                }
            }
        }.resume()
    }
    
    // MARK: - Search Google Places
    @objc private func searchTextDidChange() {
        let query = searchInputField.text ?? ""
        if query.count > 2 {
            searchGooglePlaces(query: query)
        } else {
            searchResults = []
            searchResultsTableView.reloadData()
        }
    }
    
    private func searchGooglePlaces(query: String) {
        guard let token = ShareKeychainHelper.readAccessToken() else { return }
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        guard let url = URL(string: "\(ShareAPIConfig.baseURL)/search-places?query=\(encodedQuery)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data else { return }
            
            do {
                let searchResponse = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    // Convert to SelectablePlace and check if already saved
                    self?.searchResults = searchResponse.results.map { googlePlace in
                        let isSaved = self?.allSavedPlaces.contains(where: { $0.place_id == googlePlace.place_id }) ?? false
                        return SelectablePlace(googlePlace: googlePlace, isSelected: false, isSavedOnRadar: isSaved)
                    }
                    self?.searchResultsTableView.reloadData()
                }
            } catch {
                print("Search error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Calculate Selected Unsaved Places Count
    private func selectedUnsavedPlacesCount() -> Int {
        // Count the original place if it exists and is selected
        var count = 0
        if savedPlace != nil && isMainPlaceSelected {
            count = 1
        }
        
        // Add selected search results that are NOT already saved
        count += searchResults.filter { $0.isSelected && !$0.isSavedOnRadar }.count
        
        return count
    }
    
    // MARK: - Update Button Text
    private func updateAddButtonText() {
        let count = selectedUnsavedPlacesCount()
        if count == 1 {
            addButton.setTitle("add 1 place", for: .normal)
        } else {
            addButton.setTitle("add \(count) places", for: .normal)
        }
    }
    
    // MARK: - Update UI
    private func updateUI() {
        switch currentState {
        case .loading:
            loadingContainerView.isHidden = false
            successContainerView.isHidden = true
            searchContainerView.isHidden = true
            errorContainerView.isHidden = true
            startPulseAnimation()
            
        case .success(let place):
            stopPulseAnimation()
            loadingContainerView.isHidden = true
            successContainerView.isHidden = false
            searchContainerView.isHidden = true
            errorContainerView.isHidden = true
            
            // Update place info
            placeNameLabel.text = place.name
            placeAddressLabel.text = place.address ?? "\(place.district ?? ""), Hong Kong"
            
            // Check if place is already saved on radar
            let isAlreadySaved = allSavedPlaces.contains(where: { $0.place_id == place.place_id })
            savedLabel.isHidden = !isAlreadySaved
            
            // Load Google photo
            if let photoURLString = place.photo_url,
               let photoURL = URL(string: photoURLString) {
                loadImage(from: photoURL)
            } else {
                placeImageView.backgroundColor = .systemGray6
            }
            
            // Update button text
            updateAddButtonText()
            
            // Animate in from bottom
            successContainerView.transform = CGAffineTransform(translationX: 0, y: 400)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.successContainerView.transform = .identity
            }
            
        case .searching:
            loadingContainerView.isHidden = true
            successContainerView.isHidden = true
            searchContainerView.isHidden = false
            errorContainerView.isHidden = true
            searchInputField.becomeFirstResponder()
            
        case .error(let message):
            stopPulseAnimation()
            loadingContainerView.isHidden = true
            successContainerView.isHidden = true
            searchContainerView.isHidden = true
            errorContainerView.isHidden = false
            errorMessageLabel.text = message
        }
    }
    
    // MARK: - Image Loading
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.placeImageView.image = image
            }
        }.resume()
    }
    
    // MARK: - Animations
    private func startPulseAnimation() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.loadingEmojiLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    private func stopPulseAnimation() {
        loadingEmojiLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) {
            self.loadingEmojiLabel.transform = .identity
        }
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        successBottomConstraint.constant = -keyboardFrame.height
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        successBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    @objc private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func toggleMainPlaceSelection() {
        isMainPlaceSelected.toggle()
        
        // Update checkmark icon
        if isMainPlaceSelected {
            checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
            checkmarkImageView.tintColor = .black
        } else {
            checkmarkImageView.image = UIImage(systemName: "circle")
            checkmarkImageView.tintColor = .systemGray4
        }
        
        updateAddButtonText()
        selectedPlacesTableView.reloadData()
    }
    
    @objc private func addPlaces() {
        // Get all selected unsaved places
        let selectedUnsavedResults = searchResults.filter { $0.isSelected && !$0.isSavedOnRadar }
        
        if selectedUnsavedResults.isEmpty {
            // No new places to add, just close
            closeExtension()
            return
        }
        
        // Show loading state
        addButton.isEnabled = false
        addButton.setTitle("saving...", for: .normal)
        addButton.alpha = 0.6
        
        // Save all places
        savePlaces(selectedUnsavedResults.map { $0.googlePlace }) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Show success state briefly before closing
                    self?.showSuccessAndClose(count: selectedUnsavedResults.count)
                } else {
                    // Re-enable button on error
                    self?.addButton.isEnabled = true
                    self?.addButton.setTitle("add \(selectedUnsavedResults.count) place\(selectedUnsavedResults.count == 1 ? "" : "s")", for: .normal)
                    self?.addButton.alpha = 1.0
                    
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to save some places. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func showSuccessAndClose(count: Int) {
        // Update button to show success
        addButton.setTitle("✓ saved", for: .normal)
        addButton.backgroundColor = .systemGreen
        addButton.alpha = 1.0
        
        // Close after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.closeExtension()
        }
    }
    
    private func savePlaces(_ places: [GooglePlaceResult], completion: @escaping (Bool) -> Void) {
        guard let token = ShareKeychainHelper.readAccessToken() else {
            completion(false)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true
        
        for place in places {
            dispatchGroup.enter()
            
            guard let url = URL(string: "\(ShareAPIConfig.baseURL)/add-place-by-id") else {
                allSucceeded = false
                dispatchGroup.leave()
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let payload: [String: Any] = ["place_id": place.place_id]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error saving place: \(error)")
                    allSucceeded = false
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("HTTP error: \(httpResponse.statusCode)")
                    allSucceeded = false
                }
                
                dispatchGroup.leave()
            }.resume()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allSucceeded)
        }
    }
    
    @objc private func closeSearch() {
        searchInputField.text = ""
        currentState = .success(savedPlace!)
        updateAddButtonText()
    }
}

// MARK: - UITextFieldDelegate
extension ShareViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == searchTextField {
            // Expand to full screen search
            currentState = .searching
            // Clear search input and focus it
            searchInputField.text = ""
            searchInputField.becomeFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDelegate & DataSource
extension ShareViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == searchResultsTableView {
            return searchResults.count
        } else if tableView == selectedPlacesTableView {
            // Show main place + selected search results
            var count = 0
            if savedPlace != nil && isMainPlaceSelected {
                count = 1
            }
            count += searchResults.filter { $0.isSelected }.count
            return count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == searchResultsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
            let selectablePlace = searchResults[indexPath.row]
            cell.configure(with: selectablePlace)
            return cell
        } else if tableView == selectedPlacesTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectedPlaceCell", for: indexPath) as! SelectedPlaceCell
            
            // First row is main place (if selected), rest are search results
            if indexPath.row == 0 && savedPlace != nil && isMainPlaceSelected {
                cell.configure(with: savedPlace!, isMainPlace: true, isSaved: allSavedPlaces.contains(where: { $0.place_id == savedPlace?.place_id }))
            } else {
                let selectedResults = searchResults.filter { $0.isSelected }
                let adjustedIndex = (savedPlace != nil && isMainPlaceSelected) ? indexPath.row - 1 : indexPath.row
                if adjustedIndex < selectedResults.count {
                    cell.configure(with: selectedResults[adjustedIndex])
                }
            }
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if tableView == searchResultsTableView {
            // Toggle selection
            searchResults[indexPath.row].isSelected.toggle()
            
            // Return to success screen (like Corner app)
            searchInputField.text = ""
            currentState = .success(savedPlace!)
            updateAddButtonText()
            selectedPlacesTableView.reloadData()
        } else if tableView == selectedPlacesTableView {
            // Tapping a selected place toggles its selection
            if indexPath.row == 0 && savedPlace != nil && isMainPlaceSelected {
                toggleMainPlaceSelection()
            } else {
                let selectedResults = searchResults.filter { $0.isSelected }
                let adjustedIndex = (savedPlace != nil && isMainPlaceSelected) ? indexPath.row - 1 : indexPath.row
                if adjustedIndex < selectedResults.count {
                    // Find original index in searchResults
                    if let originalIndex = searchResults.firstIndex(where: { $0.googlePlace.place_id == selectedResults[adjustedIndex].googlePlace.place_id }) {
                        searchResults[originalIndex].isSelected = false
                        selectedPlacesTableView.reloadData()
                        updateAddButtonText()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

// MARK: - Search Result Cell
class SearchResultCell: UITableViewCell {
    private let placeImageView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let checkboxView = UIView()
    private let checkmarkIcon = UIImageView()
    
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
        
        checkboxView.layer.borderWidth = 2
        checkboxView.layer.borderColor = UIColor.systemGray4.cgColor
        checkboxView.layer.cornerRadius = 15
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
            placeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            placeImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            placeImageView.widthAnchor.constraint(equalToConstant: 60),
            placeImageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: placeImageView.trailingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: checkboxView.leadingAnchor, constant: -12),
            
            checkboxView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            checkboxView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            checkboxView.widthAnchor.constraint(equalToConstant: 30),
            checkboxView.heightAnchor.constraint(equalToConstant: 30),
            
            checkmarkIcon.centerXAnchor.constraint(equalTo: checkboxView.centerXAnchor),
            checkmarkIcon.centerYAnchor.constraint(equalTo: checkboxView.centerYAnchor),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 16),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with selectablePlace: SelectablePlace) {
        let result = selectablePlace.googlePlace
        nameLabel.text = result.name
        addressLabel.text = result.address
        
        // Update checkbox appearance
        if selectablePlace.isSelected {
            checkboxView.backgroundColor = .black
            checkboxView.layer.borderColor = UIColor.black.cgColor
            checkmarkIcon.isHidden = false
        } else {
            checkboxView.backgroundColor = .white
            checkboxView.layer.borderColor = UIColor.systemGray4.cgColor
            checkmarkIcon.isHidden = true
        }
        
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
