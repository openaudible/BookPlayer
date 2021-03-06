//
//  ImportFromWebViewController.swift
//  BookPlayer
//
//  Created by OpenAudible and IOSDev on 2019-09-18
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Alamofire
import WebKit

class ImportFromWebViewController: UIViewController, UISearchBarDelegate {
    @IBOutlet weak var txtUrl: UISearchBar!

    @IBOutlet weak var viewProgress: UIView!
    @IBOutlet weak var lblDownload: UILabel!
    @IBOutlet weak var progressview: UIProgressView!
    @IBOutlet weak var webview: WKWebView! // Note this may fail on pre-iOS 11. See https://stackoverflow.com/questions/46221577

    @IBOutlet weak var browseForwardButton: UIButton!
    @IBOutlet weak var browseBackwardButton: UIButton!
    @IBOutlet weak var dismissViewButton: UIButton!

    // Content types we should try to import
    let content_types: Set = ["audio/mpeg", "audio/mp3", "audio/m4a", "audio/m4b", "application/zip"]
    // File extensions we can import
    let content_extensions: Set = ["mp3", "m4a", "m4b", "zip"]

    // credentials for URL, for host matching credential_host
    var credentials: URLCredential = URLCredential() // Use credentials for downloading book with AlamoFire.
    var credential_host = "" // the host the saved credentials are for.

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webview.uiDelegate = self
        self.webview.navigationDelegate = self
        self.webview.allowsBackForwardNavigationGestures = true
        self.webview.isHidden = false

        self.txtUrl.layer.borderWidth = 1
        self.txtUrl.layer.borderColor = #colorLiteral(red: 0.1647058824, green: 0.5176470588, blue: 0.8235294118, alpha: 1).cgColor

        self.txtUrl.delegate = self
        self.txtUrl.autocorrectionType = .no
        self.txtUrl.autocapitalizationType = .none

        self.viewProgress.isHidden = true

        self.updateButtons()

        self.browseTo(self.getSavedURL())
    }

    // This should return a user's preference for their home book page.
    // Could be their own library or librivox, etc.
    // Goal is to make average user avoid typing their most common site(s)
    // without writing an entire web browser bookmark system.

    func getSavedURL() -> String {
        return UserDefaults.standard.string(forKey: Constants.UserDefaults.webHomePage.rawValue) ?? ""
    }

    func setSavedURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: Constants.UserDefaults.webHomePage.rawValue)
    }

    override func viewDidAppear(_ animated: Bool) {}

    @IBAction func onClickCloseBtn(sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onClickBrowserBackBtn(sender: UIButton) {
        self.webview.goBack()
    }

    @IBAction func onClickBrowserForwardBtn(sender: UIButton) {
        self.webview.goForward()
    }

    // download successful.
    func successDownload() {
        let alertcontroller = UIAlertController(title: "Success", message: "Downloaded successfully", preferredStyle: .alert)
        let doneAction = UIAlertAction(title: "Done Adding", style: .default) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        let keepGoingAction = UIAlertAction(title: "Keep Browsing", style: .default) { _ in
        }
        alertcontroller.addAction(doneAction)
        alertcontroller.addAction(keepGoingAction)

        self.present(alertcontroller, animated: true, completion: nil)
    }

    @discardableResult
    func alertError(str: String) -> String {
        print("alertError:\(str)")

        let alertcontroller = UIAlertController(title: "Error", message: str, preferredStyle: .alert)
        let actionalert = UIAlertAction(title: "OK", style: .default) { _ in
        }
        alertcontroller.addAction(actionalert)
        self.present(alertcontroller, animated: true, completion: nil)

        return str
    }

    func download(url: URL, credential: URLCredential) {
        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory, in: .userDomainMask)
        self.viewProgress.isHidden = false
        AF.download(url, to: destination).response { response in
            if response.error != nil {
                self.viewProgress.isHidden = true
                self.alertError(str: "Error downloading file: \(response.error?.errorDescription ?? "")")
            }
        }.downloadProgress { progress in
            let percent = String(format: "%0.0f", progress.fractionCompleted * 100)
            let msg = "Downloading... \(percent)%"
            self.lblDownload.text = msg
            self.progressview.setProgress(Float(progress.fractionCompleted), animated: true)
        }.responseData { response in
            self.viewProgress.isHidden = true

            switch response.result {
            case .success:
                print("Download Successful")
                // TODO: Check that the file was downloaded has some content (file size > 1024?)
                let fileURL = response.fileURL!
                print("File:\(fileURL.absoluteString)")
                self.successDownload()

            case .failure(let error):
                // Delete any partial download if it exists.
                if let fileURL = response.fileURL {
                    print("deleting any partial file:\(fileURL.absoluteString)")
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        print("deleted file!")

                    } catch let error as NSError {
                        print("Error: \(error.domain)")
                    }
                }
                let msg = error.localizedDescription
                if let httpStatusCode = response.response?.statusCode {
                    print("status:\(httpStatusCode)")
                    self.alertError(str: "error \(msg)")
                }
            }
        }
    }

    func updateButtons() {
        self.browseBackwardButton.isEnabled = self.webview.canGoBack
        self.browseForwardButton.isEnabled = self.webview.canGoForward
    }

    func downloadAction(url: URL) {
        self.download(url: url, credential: self.credentials)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { // called when keyboard search button pressed
        self.browseTo(self.txtUrl.text)
    }

    // Go to web url specified. can be google.com, http://foo.bar.
    func browseTo(_ url: String?) {
        if let urlString = url, !urlString.isEmpty {
            // string is not nil and not empty...

            let u = urlString.starts(with: "http://") || urlString.starts(with: "https://") ? urlString : "http://\(urlString)"

            self.txtUrl.text = u
            self.webview.load(URLRequest(url: URL(string: u)!))
            self.setSavedURL(u)
        }
    }
}

extension ImportFromWebViewController: WKUIDelegate {}

extension ImportFromWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    /*! @abstract Decides whether to allow or cancel a navigation after its
     response is known.
     @param webView The web view invoking the delegate method.
     @param navigationResponse Descriptive information about the navigation
     response.
     @param decisionHandler The decision handler to call to allow or cancel the
     navigation. The argument is one of the constants of the enumerated type WKNavigationResponsePolicy.
     @discussion If you do not implement this method, the web view will allow the response, if the web view can show it.
     */
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let url = navigationResponse.response.url!
            let content_type = response.allHeaderFields["Content-Type"] as? String
            let type_ok = self.content_types.contains(content_type!)
            let extension_ok = self.content_extensions.contains(url.pathExtension)
            // allow audio content type, zip... or urls ending in .mp3, .m4a, zip, etc...
            let isDownloadable = type_ok || extension_ok

            if isDownloadable {
                decisionHandler(.cancel)
                // print("allHeaders = \(response.allHeaderFields)")
                self.downloadAction(url: webView.url!)
                // print("finished self.downloadAction = \(webView.url!)")

                if self.webview.canGoBack {
                    self.webview.goBack()
                    self.webview.reload()
                }
            } else {
                // print("decidePolicyFor navigationResponse = \(url) and content \(content_type!)")
                decisionHandler(.allow)
            }
        }
    }

    /*! @abstract Invoked when a main frame navigation starts.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.
     */
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // print("didStartProvisionalNavigation \(self.webview.url)")
    }

    /*! @abstract Invoked when a server redirect is received for the main
     frame.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.
     */
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        // print("webViewWebContentProcessDidTerminate \(self.webview.url)")
    }

    /*! @abstract Invoked when content starts arriving for the main frame.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.

     func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
     // print("didCommit navigation \(self.webview.url)")
     }

     */

    /*! @abstract Invoked when an error occurs while starting to load data for
     the main frame.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.
     @param error The error that occurred.
     */
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // print("didFailProvisionalNavigation \(self.webview.url) with error \(error)")

        // NSError code 102 means the page was aborted.. which happens when a book is being downloaded.
        if (error as NSError).code != 102 {
            self.alertError(str: "Error accessing page: \(error.localizedDescription)")
        }
    }

    /*! @abstract Invoked when a main frame navigation completes.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let u = self.webview.url {
            self.txtUrl.text = u.absoluteString
        }
        self.updateButtons()
    }

    /*! @abstract Invoked when an error occurs during a committed main frame
     navigation.
     @param webView The web view invoking the delegate method.
     @param navigation The navigation.
     @param error The error that occurred.
     */
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // print("didFail navigation \(self.webview.url)")
    }

    /*! @abstract Invoked when the web view needs to respond to an authentication challenge.
     @param webView The web view that received the authentication challenge.
     @param challenge The authentication challenge.
     @param completionHandler The completion handler you must invoke to respond to the challenge. The
     disposition argument is one of the constants of the enumerated type
     NSURLSessionAuthChallengeDisposition. When disposition is NSURLSessionAuthChallengeUseCredential,
     the credential argument is the credential to use, or nil to indicate continuing without a
     credential.
     @discussion If you do not implement this method, the web view will respond to the authentication challenge with the NSURLSessionAuthChallengeRejectProtectionSpace disposition.
     */
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                                                                                       URLCredential?) -> Void) {
        guard let hostname = webView.url?.host else {
            return
        }
        // print("didReceive challenge \(hostname) & \(self.credential_host)")

        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        if authenticationMethod == NSURLAuthenticationMethodDefault || authenticationMethod == NSURLAuthenticationMethodHTTPBasic || authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
            let av = UIAlertController(title: webView.title, message: String(format: "AUTH_CHALLENGE_REQUIRE_PASSWORD", hostname), preferredStyle: .alert)
            av.addTextField(configurationHandler: { textField in
                textField.placeholder = "User"
            })
            av.addTextField(configurationHandler: { textField in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            })

            av.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                guard let userId = av.textFields?.first?.text else {
                    return
                }
                guard let password = av.textFields?.last?.text else {
                    return
                }
                let credential = URLCredential(user: userId, password: password, persistence: .forSession)
                print("setting credentials for \(userId)")
                self.credentials = credential
                self.credential_host = hostname

                completionHandler(.useCredential, credential)
            }))
            av.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                completionHandler(.cancelAuthenticationChallenge, nil)
            }))
            self.present(av, animated: true, completion: nil)
        } else if authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /*! @abstract Invoked when the web view's web content process is terminated.
     @param webView The web view whose underlying web content process was terminated.
     */
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // print("webViewWebContentProcessDidTerminate \(self.webview.url)")
    }
}
