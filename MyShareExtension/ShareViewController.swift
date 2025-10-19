import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleIncomingItems()
    }

    private func handleIncomingItems() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeExtension()
            return
        }

        // Parcourt les pièces jointes du share sheet
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier,
                                  options: nil) { [weak self] item, error in
                    guard let self else { return }
                    if let url = item as? URL {
                        self.saveURL(url)
                    }
                    self.completeExtension()
                }
                return
            }

            // Fallback si l’app-source n’envoie que du texte
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier,
                                  options: nil) { [weak self] item, _ in
                    guard let self else { return }
                    if let text = item as? String, let url = URL(string: text) {
                        self.saveURL(url)
                    }
                    self.completeExtension()
                }
                return
            }
        }

        // Rien trouvé ?
        completeExtension()
    }

    private func saveURL(_ url: URL) {
        // Exemple via App Group
        let sharedDefaults = UserDefaults(suiteName: "group.com.votreSociete.votreApp")
        sharedDefaults?.set(url.absoluteString, forKey: "lastSharedURL")
        sharedDefaults?.synchronize()
    }

    private func completeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

