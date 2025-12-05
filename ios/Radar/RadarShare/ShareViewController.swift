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
        
        print("[ShareExtension] Keychain status with App Groups: \(status)")
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            print("[ShareExtension] ✅ Found token with App Groups")
            return token
        }
        
        // Fallback: Try without App Groups (old method)
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true
        ]
        
        result = nil
        status = SecItemCopyMatching(query as CFDictionary, &result)
        
        print("[ShareExtension] Keychain status without App Groups: \(status)")
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            print("[ShareExtension] ✅ Found token without App Groups")
            return token
        }
        
        print("[ShareExtension] ❌ No token found")
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
    let category: String  // Required field from backend
    let emoji: String     // Required field from backend
    let photo_url: String?
    let rating: Double?
    let is_visited: Bool
    let is_favorite: Bool
    let tags: [String]?
    let source_url: String?
    let created_at: String
}

struct ErrorResponse: Codable {
    let detail: String
}

// MARK: - Share View Controller
class ShareViewController: UIViewController {
    
    private var sharedURL: String?
    
    // UI Elements
    private let containerView = UIView()
    private let emojiLabel = UILabel()
    private let statusLabel = UILabel()
    private let placeNameLabel = UILabel()
    private let addressLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    
    private enum State {
        case loading
        case success(PlaceResponse)
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
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 24
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.2
        containerView.layer.shadowOffset = CGSize(width: 0, height: 10)
        containerView.layer.shadowRadius = 20
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Emoji (large, animated)
        emojiLabel.text = "🌍"
        emojiLabel.font = .systemFont(ofSize: 80)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(emojiLabel)
        
        // Status label
        statusLabel.text = "finding your next hangout spot..."
        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // Place name (hidden initially)
        placeNameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        placeNameLabel.textAlignment = .center
        placeNameLabel.numberOfLines = 0
        placeNameLabel.alpha = 0
        placeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(placeNameLabel)
        
        // Address (hidden initially)
        addressLabel.font = .systemFont(ofSize: 16)
        addressLabel.textAlignment = .center
        addressLabel.textColor = .secondaryLabel
        addressLabel.numberOfLines = 0
        addressLabel.alpha = 0
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(addressLabel)
        
        // Close button (hidden initially)
        closeButton.setTitle("Done", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        closeButton.backgroundColor = UIColor(red: 0.99, green: 0.45, blue: 0.22, alpha: 1.0) // #FC7339
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 12
        closeButton.alpha = 0
        closeButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            emojiLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            emojiLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            placeNameLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 24),
            placeNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            placeNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            addressLabel.topAnchor.constraint(equalTo: placeNameLabel.bottomAnchor, constant: 12),
            addressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            addressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            closeButton.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 32),
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32)
        ])
        
        // Start pulse animation
        startPulseAnimation()
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
                        self?.importPlace()
                    } else {
                        self?.currentState = .error("Could not read URL")
                    }
                }
            }
        } else {
            currentState = .error("Please share an Instagram post")
        }
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
                    self?.currentState = .success(place)
                } catch {
                    self?.currentState = .error("Failed to parse response")
                }
            }
        }.resume()
    }
    
    // MARK: - Update UI Based on State
    private func updateUI() {
        switch currentState {
        case .loading:
            emojiLabel.text = "🌍"
            statusLabel.text = "finding your next hangout spot..."
            statusLabel.alpha = 1
            placeNameLabel.alpha = 0
            addressLabel.alpha = 0
            closeButton.alpha = 0
            startPulseAnimation()
            
        case .success(let place):
            stopPulseAnimation()
            
            // Update emoji to place category
            emojiLabel.text = place.emoji ?? "📍"
            
            // Hide status, show place info
            UIView.animate(withDuration: 0.3) {
                self.statusLabel.alpha = 0
            } completion: { _ in
                self.placeNameLabel.text = place.name
                self.addressLabel.text = place.district ?? place.address ?? ""
                
                UIView.animate(withDuration: 0.4) {
                    self.placeNameLabel.alpha = 1
                    self.addressLabel.alpha = 1
                    self.closeButton.alpha = 1
                }
            }
            
            // Bounce animation for emoji
            emojiLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
                self.emojiLabel.transform = .identity
            }
            
        case .error(let message):
            stopPulseAnimation()
            emojiLabel.text = "⚠️"
            statusLabel.text = message
            statusLabel.textColor = .systemRed
            
            // Show close button
            UIView.animate(withDuration: 0.3, delay: 0.5) {
                self.closeButton.alpha = 1
            }
        }
    }
    
    // MARK: - Animations
    private func startPulseAnimation() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.emojiLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    private func stopPulseAnimation() {
        emojiLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) {
            self.emojiLabel.transform = .identity
        }
    }
    
    // MARK: - Actions
    @objc private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
