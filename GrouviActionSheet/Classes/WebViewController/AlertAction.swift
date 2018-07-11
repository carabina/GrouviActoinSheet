import UIKit

open class AlertAction {
    public enum Style {
        case `default`
        case ok
        case cancel
        case destructive
    }
    
    public init(title: String, style: Style, bottomBorder: Bool = true, handler: ((AlertAction?) -> Void)? = nil) {
        self.title = title
        self.handler = handler
        self.style = style
        self.bottomBorder = bottomBorder
    }
    
    public convenience init(title: String, style: Style, dismissesAlert: Bool, handler: ((AlertAction?) -> Void)? = nil, bottomBorder: Bool = true) {
        self.init(title: title, style: style,  bottomBorder: bottomBorder, handler: handler)
        self.dismissesAlert = dismissesAlert
    }
    
    public var title: String {
        didSet {
            button?.setTitle(title, for: .normal)
        }
    }
    public var handler: ((AlertAction) -> Void)?
    public var style: Style
    public var isHidden: Bool = false
    public var bottomBorder: Bool

    public var dismissesAlert = true
    open var enabled: Bool = true {
        didSet {
            button?.isEnabled = enabled
        }
    }
    open fileprivate(set) var button: UIButton!
    
    public func setButton(_ forButton: UIButton) {
        button = forButton
        button.setTitle(title, for: UIControlState())
        button.isEnabled = enabled
    }
}
