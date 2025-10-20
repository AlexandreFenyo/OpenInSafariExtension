internal import System
import UIKit
import UniformTypeIdentifiers
import os

/* https://blog.tibimac.com/2024/01/resoudre-erreur-exsinkloadoperator-nsitemprovider/
 L'erreur suivante est normale avec Swift plutôt qu'Objective-C :
 <NSItemProvider: 0x103f35340> {types = (
     "public.url"
 )}
 -[_EXSinkLoadOperator loadItemForTypeIdentifier:completionHandler:expectedValueClass:options:] nil expectedValueClass allowing {(
     NSValue,
     NSNumber,
     NSError,
     NSMutableString,
     NSArray,
     NSURL,
     NSDictionary,
     NSString,
     NSData,
     NSUUID,
     NSDate,
     NSMutableArray,
     NSMutableData,
     NSMutableDictionary,
     UIImage,
     CKShare,
     _EXItemProviderSandboxedResource
 )}
 */

private let logger = Logger(subsystem: "com.net.fenyo.openinsafari", category: "ShareExtension")

final class ShareViewController: UIViewController {

    // https://medium.com/@damisipikuda/how-to-receive-a-shared-content-in-an-ios-application-4d5964229701
    // Courtesy: https://stackoverflow.com/a/44499222/13363449
    // Function must be named exactly like this so a selector can be found by the compiler!
    // Anyway - it's another selector in another instance that would be "performed" instead.
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(#selector(openURL(_:)), with: url) != nil
            }
            responder = responder?.next
        }
        return false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleIncomingItems()
    }

    private func handleIncomingItems() {

        print(extensionContext)

        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finishWithFailure()
            return
        }

        extractFirstURL(from: extensionItems) { [weak self] url in
            guard let self = self, let url = url else {
                self?.finishWithFailure()
                return
            }

            // Important : on doit effectuer l’appel sur le thread principal
            DispatchQueue.main.async {
                print(url)

                /*
                self.extensionContext?.open(/*url*/URL("https://www.x.org")!, completionHandler: { success in
                    if success {
                        self.extensionContext?.completeRequest(returningItems: nil)
                    } else {
                        self.finishWithFailure()
                    }
                }
                )*/
            }
        }
    }

    private func extractFirstURL(
        from items: [NSExtensionItem],
        completion: @escaping (URL?) -> Void
    ) {

        let group = DispatchGroup()
        var foundURL: URL?

        for item in items {
            guard let providers = item.attachments else { continue }

            let foo = providers.first!
            print(foo)

            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {

                /*
                if #available(iOS 14.0, *) {
                    guard provider.hasItemConforming(to: UTType.url) else { continue }
                } else {
                    guard provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) else { continue }
                }*/

                group.enter()

                print(provider)

                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    // May be run in a background thread

                    if let error {
                        print("ERROR: \(error)")
                    } else {
                        print("NO ERROR")
                    }

                    defer { group.leave() }
                    if let item {
                        guard let url = URL(string: "openinsafari://share") else { return }
                        logger.error("avant ouverture")
                        self.extensionContext?.open(
                            url,
                            completionHandler: { success in
                                print("Ouverture de l'URL : \(success)")
                                logger.error("après ouverture")
                            }
                        )
                        print("item: \(item)")
                    }
                }

            }

        }

        group.notify(queue: .main) {
            print("group.notify()")
            completion(foundURL)
        }
    }

    private func finishWithFailure() {
        let error = NSError(
            domain: "OpenInSafariExtension",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Impossible de récupérer l’URL."]
        )
        extensionContext?.cancelRequest(withError: error)
    }
}
