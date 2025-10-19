import UIKit
import UniformTypeIdentifiers
internal import System

/*
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

final class ShareViewController: UIViewController {

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
                self.extensionContext?.open(/*url*/URL("https://www.x.org")!, completionHandler: { success in
                    if success {
                        self.extensionContext?.completeRequest(returningItems: nil)
                    } else {
                        self.finishWithFailure()
                    }
                })
            }
        }
    }

    private func extractFirstURL(from items: [NSExtensionItem],
                                 completion: @escaping (URL?) -> Void) {

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
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier as String, options: nil) { (item, error) in
                    defer { group.leave() }

                    print(item)
                    /*
                    if let url = item as? URL {
                        foundURL = url
                    } else if let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) {
                        foundURL = url
                    }*/
                }
            }

        }

        group.notify(queue: .main) {
            completion(foundURL)
        }
    }

    private func finishWithFailure() {
        let error = NSError(domain: "OpenInSafariExtension",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Impossible de récupérer l’URL."])
        extensionContext?.cancelRequest(withError: error)
    }
}
