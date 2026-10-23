import AuthenticationServices
import Cocoa
import FlutterMacOS
import window
import LaunchAtLogin

final class IpingAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var window: NSWindow?
    private var session: ASWebAuthenticationSession?

    init(window: NSWindow) {
        self.window = window
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "authenticate":
            guard session == nil,
                  let arguments = call.arguments as? [String: Any],
                  let url = (arguments["url"] as? String).flatMap(URL.init(string:)),
                  let scheme = arguments["callbackUrlScheme"] as? String
            else {
                result(FlutterError(code: "INVALID_REQUEST", message: nil, details: nil))
                return
            }
            let completion: (URL?, Error?) -> Void = { [weak self] url, error in
                DispatchQueue.main.async {
                    self?.session = nil
                    if let url {
                        result(url.absoluteString)
                    } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        result(nil)
                    } else {
                        result(FlutterError(code: "FAILED", message: error?.localizedDescription, details: nil))
                    }
                }
            }
            let session: ASWebAuthenticationSession
            if #available(macOS 14.4, *) {
                session = ASWebAuthenticationSession(
                    url: url, callback: .customScheme(scheme), completionHandler: completion)
            } else {
                session = ASWebAuthenticationSession(
                    url: url, callbackURLScheme: scheme, completionHandler: completion)
            }
            session.presentationContextProvider = self
            // Share the browser's cookies so an existing web login is reused.
            session.prefersEphemeralWebBrowserSession = false
            guard session.start() else {
                result(FlutterError(code: "FAILED", message: "Unable to start the login session", details: nil))
                return
            }
            self.session = session
        case "cancel":
            session?.cancel()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }
}

class MainFlutterWindow: NSWindow {
    private var authSession: IpingAuthSession?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        let authSession = IpingAuthSession(window: self)
        self.authSession = authSession
        FlutterMethodChannel(
            name: "iping/auth_session", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler(authSession.handle)

        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
