import UIKit
import GrouviExtensionKit

open class AlertController: UIViewController {
    public enum Style {
        case alert
        case actionSheet
    }
    
    @IBOutlet fileprivate weak var containerView: UIView!
    @IBOutlet fileprivate weak var backgroundView: RespondView!
    @IBOutlet fileprivate weak var coverView: UIView!
    @IBOutlet fileprivate weak var marginView: UIView!
    @IBOutlet fileprivate weak var baseView: UIView!
    @IBOutlet fileprivate weak var mainView: UIScrollView!
    @IBOutlet fileprivate weak var buttonView: UIScrollView!
    @IBOutlet fileprivate weak var cancelButtonView: UIScrollView!
    @IBOutlet fileprivate weak var contentView: AlertContentView?
    
    @IBOutlet fileprivate var containerViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var containerViewBottomSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var backgroundViewTopSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var backgroundViewBottomSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var coverViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet fileprivate var mainViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var buttonViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var cancelButtonViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var buttonViewSpaceConstraint: NSLayoutConstraint!
    
    @IBOutlet fileprivate var marginViewTopSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var marginViewLeftSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var marginViewBottomSpaceConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var marginViewRightSpaceConstraint: NSLayoutConstraint!
    
    open var configContainerWidth: (() -> CGFloat?)?
    open var configContainerCornerRadius: (() -> CGFloat?)?
    open var configContentView: ((UIView?) -> Void)?
    open var needSmallView: ((Bool) -> Void)?
    open var dismissAlertController: (() -> Void)?


    open fileprivate(set) var actions: [AlertAction] = []
    open fileprivate(set) var textFields: [UITextField] = []

    open var coverColor = UIColor.black.withAlphaComponent(0.6)
    open var buttonBackgroundColor: UIColor?
    open var buttonTintColor: UIColor?
    open var dividerColor: UIColor?

    fileprivate var textFieldHandlers: [((UITextField?) -> Void)?] = []
    fileprivate var customView: UIView?
    fileprivate var transitionCoverView: UIView?
    fileprivate var displayTargetView: UIView?
    fileprivate var presentedAnimation: Bool = true
    let AlertDefaultWidth: CGFloat = 270
    let AlertButtonHeight: CGFloat = 58
    let AlertButtonFontSize: CGFloat = 14
    let ActionSheetMargin: CGFloat = 8
    let ActionSheetButtonHeight: CGFloat = 58
    let ActionSheetButtonFontSize: CGFloat = 21
    let ConstraintPriorityRequired: Float = 1000

    fileprivate var originalCenter = CGPoint.zero

    fileprivate var message: String?
    fileprivate var preferredStyle: Style = .alert
    
    fileprivate var marginInsets: UIEdgeInsets {
        set {
            marginViewTopSpaceConstraint.constant = newValue.top
            marginViewLeftSpaceConstraint.constant = newValue.left
            marginViewBottomSpaceConstraint.constant = newValue.bottom
            marginViewRightSpaceConstraint.constant = newValue.right
        }
        get {
            let top = marginViewTopSpaceConstraint.constant
            let left = marginViewLeftSpaceConstraint.constant
            let bottom = marginViewBottomSpaceConstraint.constant
            let right = marginViewRightSpaceConstraint.constant
            return UIEdgeInsetsMake(top, left, bottom, right)
        }
    }
    
    public convenience init() {
        self.init(nibName: "SimpleAlert", bundle: Bundle(for: AlertController.self))
    }
    
    public convenience init(title: String? = nil, message: String? = nil, style: Style) {
        self.init()
        self.title = title
        self.message = message
        self.preferredStyle = style
    }
    
    public convenience init(view: UIView?, style: Style) {
        self.init()
        self.customView = view
        self.preferredStyle = style
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        modalPresentationStyle = .custom
        modalTransitionStyle = .crossDissolve
        transitioningDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(AlertController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AlertController.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        baseView.layer.cornerRadius = 10.0
        baseView.clipsToBounds = true
        
        cancelButtonView.layer.cornerRadius = 10.0
        cancelButtonView.clipsToBounds = true
        
        displayTargetView = contentView
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        view.addGestureRecognizer(panGestureRecognizer)

        if let view = customView {
            displayTargetView = view
        }
        
        if displayTargetView == contentView {
            setupContentView()
        }
        textFieldHandlers.removeAll()
        
        if let textField = textFields.first {
            textField.becomeFirstResponder()
        }
        
        if preferredStyle == .actionSheet {
            containerViewBottomSpaceConstraint.priority = UILayoutPriority(rawValue: ConstraintPriorityRequired)
            backgroundView.touchHandler = { [weak self] view in
                self?.dismiss()
            }
        }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if transitionCoverView == nil {
            return
        }
        
        layoutContainer()
        layoutContents()
        UIView.performWithoutAnimation {
            layoutButtons()
        }

        let margin = marginInsets.top + marginInsets.bottom
        let backgroundViewHeight = view.bounds.size.height - backgroundViewBottomSpaceConstraint.constant - margin
        
        if cancelButtonView.contentSize.height > cancelButtonViewHeightConstraint.constant {
            cancelButtonViewHeightConstraint.constant = cancelButtonView.contentSize.height
        }
        
        if cancelButtonViewHeightConstraint.constant > backgroundViewHeight {
            cancelButtonView.contentSize.height = cancelButtonViewHeightConstraint.constant
            cancelButtonViewHeightConstraint.constant = backgroundViewHeight
            
            mainViewHeightConstraint.constant = 0
            buttonViewHeightConstraint.constant = 0
        } else {
            let baseViewHeight = backgroundViewHeight - cancelButtonViewHeightConstraint.constant - buttonViewSpaceConstraint.constant

            let requiredHeight = addButton(nil, actions: actions.filter { $0.style != .cancel }) + mainViewHeightConstraint.constant
            if requiredHeight < baseViewHeight {
                needSmallView?(false)
            }

            if buttonView.contentSize.height > buttonViewHeightConstraint.constant {
                buttonViewHeightConstraint.constant = buttonView.contentSize.height
            }
            
            if buttonViewHeightConstraint.constant > baseViewHeight {
                buttonView.contentSize.height = buttonViewHeightConstraint.constant
                buttonViewHeightConstraint.constant = baseViewHeight
                mainViewHeightConstraint.constant = 0
            } else {
                let mainViewHeight = baseViewHeight - buttonViewHeightConstraint.constant
                if mainViewHeightConstraint.constant > mainViewHeight {
                    mainView.contentSize.height = mainViewHeightConstraint.constant
                    mainViewHeightConstraint.constant = mainViewHeight
                    needSmallView?(true)
                }
            }
        }
        
        if preferredStyle == .actionSheet {
            let contentHeight = cancelButtonViewHeightConstraint.constant + mainViewHeightConstraint.constant + buttonViewHeightConstraint.constant + buttonViewSpaceConstraint.constant
            coverViewHeightConstraint.constant = contentHeight + marginInsets.top + marginInsets.bottom
        }
        
        view.layoutSubviews()
    }

    public func show(alwaysOnTop: Bool = false) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        if alwaysOnTop {
            window.windowLevel = 10000001
        } else {
            UIApplication.shared.sendAction(#selector(resignFirstResponder), to:nil, from:nil, for:nil)
        }
        window.isHidden = false
        window.rootViewController?.present(self, animated: true, completion: nil)
    }

    open func addTextFieldWithConfigurationHandler(_ configurationHandler: ((UITextField?) -> Void)? = nil) {
        textFieldHandlers.append(configurationHandler)
    }
    
    open func addAction(_ action: AlertAction) {
        var buttonHeight: CGFloat!
        if preferredStyle == .actionSheet {
            buttonHeight = ActionSheetButtonHeight
        } else {
            buttonHeight = AlertButtonHeight
        }
        
        let button = loadButton(bottomBorder: action.bottomBorder)
        if button.bounds.height <= 0 {
            button.frame.size.height = buttonHeight
        }
        button.autoresizingMask = .flexibleWidth
        button.addTarget(self, action: #selector(AlertController.buttonWasTapped(_:)), for: .touchUpInside)
        action.setButton(button)
        configureButton(action.style, forButton: button)
        actions.append(action)
    }
    
    /** override if needed */
    open func loadButton(bottomBorder: Bool = true) -> UIButton {
        let button = UIButton(type: .system)
        if bottomBorder {
            let borderView = UIView(frame: CGRect(x: 0, y: -1 / UIScreen.main.scale, width: 0, height: 1 / UIScreen.main.scale))
            borderView.backgroundColor = dividerColor ?? UIColor(hex: 0xc7c7c7)
            borderView.autoresizingMask = .flexibleWidth
            button.addSubview(borderView)
        }
        return button
    }
    
    open func configureButton(_ style: AlertAction.Style, forButton button: UIButton) {
        if preferredStyle == .alert {
            configureAlertButton(style, forButton: button)
        } else {
            configureActionSheetButton(style, forButton: button)
        }
    }

    @objc func handlePanGesture(gesture: UIPanGestureRecognizer) {
        switch (gesture.state) {
        case .began:
                originalCenter = marginView.center
            break
        case .ended:
            let velocity = gesture.velocity(in: view)
             if velocity.y < 0 {
                moveMarginViewToPoint(originalCenter)
            } else {
                dismiss()
            }
            break
        case .changed:
            let translation = gesture.translation(in: view)
            let ty = marginView.center.y <= originalCenter.y ? 80 * tanh(translation.y / 150) : translation.y
            let center = CGPoint(x: originalCenter.x, y: originalCenter.y + ty)
            marginView.center = center
            break
        default:
            dismiss()
            break
        }
    }

    func moveMarginViewToPoint(_ center: CGPoint) {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: {
            self.marginView.center = center
        })
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

private extension AlertContentView {
    class ContentTextField: UITextField {
        let TextLeftOffset: CGFloat = 4
        override func textRect(forBounds bounds: CGRect) -> CGRect {
            return bounds.offsetBy(dx: TextLeftOffset, dy: 0)
        }
        
        override func editingRect(forBounds bounds: CGRect) -> CGRect {
            return bounds.offsetBy(dx: TextLeftOffset, dy: 0)
        }
    }
    
    func addTextField() -> UITextField {
        let textField = ContentTextField(frame: textBackgroundView.bounds)
        textField.autoresizingMask = .flexibleWidth
        textField.font = UIFont.systemFont(ofSize: TextFieldFontSize)
        textField.backgroundColor = UIColor.white
        textField.layer.borderColor = UIColor.darkGray.cgColor
        textField.layer.borderWidth = 0.5
        
        textBackgroundView.addSubview(textField)
        
        return textField
    }
    
    func layoutContents() {
        titleLabel.preferredMaxLayoutWidth = baseView.bounds.width
        titleLabel.layoutIfNeeded()
        messageLabel.preferredMaxLayoutWidth = baseView.bounds.width
        messageLabel.layoutIfNeeded()
        
        if textBackgroundView.subviews.isEmpty {
            messageSpaceConstraint.constant = 0
        }
        
        if titleLabel.text == nil && messageLabel.text == nil {
            titleSpaceConstraint.constant = 0
            messageSpaceConstraint.constant = 0
            
            if textBackgroundView.subviews.isEmpty {
                verticalSpaceConstraint.constant = 0
            }
        } else if titleLabel.text == nil || messageLabel.text == nil {
            titleSpaceConstraint.constant = 0
        }
        
        baseView.setNeedsLayout()
        baseView.layoutIfNeeded()
        
        frame.size.height = baseView.bounds.height + (verticalSpaceConstraint.constant * 2)
    }
    
    func layoutTextField(_ textField: UITextField) {
        textField.frame.origin.y = textViewHeightConstraint.constant
        if textField.frame.height <= 0 {
            textField.frame.size.height = TextFieldHeight
        }
        textViewHeightConstraint.constant += textField.frame.height
    }
}

private extension AlertController {
    func setupContentView() {
        takeOverColor(contentView)

        contentView?.titleLabel.text = title
        contentView?.messageLabel.text = message
        
        if preferredStyle == .alert {
            for handler in textFieldHandlers {
                if let textField = self.contentView?.addTextField() {
                    self.textFields.append(textField)
                    handler?(textField)
                }
            }
        }
    }
    
    func layoutContainer() {
        var containerWidth = AlertDefaultWidth
        if preferredStyle == .actionSheet {
            let safeInsets = LayoutHelper.instance.safeInsets(for: view)
            marginInsets = UIEdgeInsetsMake(ActionSheetMargin + safeInsets.top, ActionSheetMargin + safeInsets.left, ActionSheetMargin + safeInsets.bottom, ActionSheetMargin + safeInsets.right)
            marginView.layoutIfNeeded()
            containerWidth = min(view.bounds.width, view.bounds.height) - marginInsets.left - marginInsets.right
        }
        
        if let width = configContainerWidth?() {
            containerWidth = width
        }
        if let radius = configContainerCornerRadius?() {
            baseView.layer.cornerRadius = radius
            cancelButtonView.layer.cornerRadius = radius
        }
        
        containerViewWidthConstraint.constant = containerWidth
        containerView.layoutIfNeeded()
    }
    
    func layoutContents() {
        displayTargetView?.frame.size.width = mainView.frame.size.width
        displayTargetView?.layoutIfNeeded()
        
        if let config = configContentView {
            config(displayTargetView)
            configContentView = nil
        }
        takeOverColor(displayTargetView)

        if displayTargetView == contentView {
            contentView?.textViewHeightConstraint.constant = 0
            for textField in textFields {
                contentView?.layoutTextField(textField)
            }
            contentView?.layoutContents()
        }
        
        if let targetView = displayTargetView {
            mainViewHeightConstraint.constant = targetView.bounds.height
            mainView.frame.size.height = targetView.bounds.height
            mainView.addSubview(targetView)
        }
    }
    
    func layoutButtons() {
        var buttonActions = actions
        if preferredStyle == .actionSheet {
            let cancelActions = actions.filter { $0.style == .cancel }
            let buttonHeight = addButton(cancelButtonView, actions: cancelActions)
            cancelButtonViewHeightConstraint.constant = buttonHeight
            buttonViewSpaceConstraint.constant = ActionSheetMargin
            
            buttonActions = actions.filter { $0.style != .cancel }
        }
        
        let buttonHeight = addButton(buttonView, actions: buttonActions)
        if self.preferredStyle != .alert || buttonActions.count != 2 {
            self.buttonViewHeightConstraint.constant = buttonHeight
        }
    }

    func takeOverColor(_ targetView: UIView?) {
        if let color = targetView?.backgroundColor {
            mainView.backgroundColor = color
            buttonView.backgroundColor = buttonBackgroundColor ?? color
            cancelButtonView.backgroundColor = buttonBackgroundColor ?? color
            if let buttonTintColor = buttonTintColor {
                buttonView.tintColor = buttonTintColor
                cancelButtonView.tintColor = buttonTintColor
            }
        }
        targetView?.backgroundColor = nil
    }

    func addButton(_ view: UIView?, actions: [AlertAction]) -> CGFloat {
        var sizeToFit: ((_ button: UIButton, _ index: Int) -> Void) = buttonSizeToFitForVertical
        if preferredStyle == .alert && actions.count == 2 {
            sizeToFit = buttonSizeToFitForHorizontal
        }
        
        return actions.reduce(0) { height, action in
            let button = action.button
            if action.isHidden && view != nil {
                button!.removeFromSuperview()
                return height
            } else {
                view?.addSubview(button!)

                let buttonHeight = Int((button?.bounds.height)!)
                let buttonsHeight = Int(height)
                sizeToFit(button!, buttonsHeight / buttonHeight)
                button?.layoutIfNeeded()

                return CGFloat(buttonsHeight + buttonHeight)
            }
        }
    }
    
    func buttonSizeToFitForVertical(_ button: UIButton, index: Int) {
        button.frame.size.width = containerViewWidthConstraint.constant
        button.frame.origin.y = button.bounds.height * CGFloat(index)
    }
    
    func buttonSizeToFitForHorizontal(_ button: UIButton, index: Int) {
        button.frame.size.width = containerViewWidthConstraint.constant / 2
        button.frame.origin.x = button.bounds.width * CGFloat(index)
        
        if index != 0 {
            let borderView = UIView(frame: CGRect(x: 0, y: 0, width: 0.5, height: button.bounds.height))
            borderView.backgroundColor = UIColor.lightGray
            borderView.autoresizingMask = .flexibleHeight
            button.addSubview(borderView)
        }
    }
    
    func configureAlertButton(_ style :AlertAction.Style, forButton button: UIButton) {
        switch style {
        case .destructive:
            button.setTitleColor(UIColor.red, for: UIControlState())
            button.titleLabel?.font = UIFont.systemFont(ofSize: AlertButtonFontSize)
        case .cancel:
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: AlertButtonFontSize)
        default:
            button.titleLabel?.font = UIFont.systemFont(ofSize: AlertButtonFontSize)
        }
    }
    
    func configureActionSheetButton(_ style :AlertAction.Style, forButton button: UIButton) {
        switch style {
        case .destructive:
            button.setTitleColor(UIColor.red, for: UIControlState())
            button.titleLabel?.font = UIFont.systemFont(ofSize: ActionSheetButtonFontSize)
        case .cancel:
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: ActionSheetButtonFontSize)
        default:
            button.titleLabel?.font = UIFont.systemFont(ofSize: ActionSheetButtonFontSize)
        }
    }
    
    func dismissViewController(_ sender: AnyObject? = nil) {
        guard let action = self.actions.filter({ $0.button == sender as? UIButton }).first else {
            dismiss()
            return
        }
        if action.dismissesAlert {
            dismiss {
                action.handler?(action)
            }
        } else {
            action.handler?(action)
        }
    }

    func dismiss(withCompletion block: @escaping () -> () = {}) {
        dismissAlertController?()
        dismiss(animated: true) {
            block()
            self.actions.removeAll()
            self.textFields.removeAll()
        }
    }
}

// MARK: - Action Methods
private extension AlertController {
    @objc dynamic func buttonWasTapped(_ sender: UIButton) {
        dismissViewController(sender)
    }
}

// MARK: - NSNotificationCenter Methods
extension AlertController {
    @objc func keyboardDidHide(_ notification: Notification) {
        backgroundViewBottomSpaceConstraint?.constant = 0
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let window = view.window {
            if let frame = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue {
                _ = window.convert(frame, to: view)
                
                //align alert to keyboard size. Trouble with accessoryViews
                backgroundViewBottomSpaceConstraint?.constant = 0 //view.bounds.size.height - rect.origin.y
            }
        }
    }
}

// MARK: - UIViewControllerTransitioningDelegate Methods
extension AlertController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedAnimation = true
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedAnimation = false
        return self
    }
}

// MARK: - UIViewControllerAnimatedTransitioning Methods
extension AlertController: UIViewControllerAnimatedTransitioning {
    func animateDuration() -> TimeInterval {
        return 0.35
    }
    
    func animationOptionsForAnimationCurve(_ curve: UInt) -> UIViewAnimationOptions {
        return UIViewAnimationOptions(rawValue: curve << 16)
    }
    
    func createCoverView(_ frame: CGRect) -> UIView {
        let coverView = UIView(frame: frame)
        coverView.backgroundColor = self.coverColor
        coverView.alpha = 0
        coverView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return coverView
    }
    
    func animation(_ animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        UIView.animate(withDuration: animateDuration(), delay: 0, options: animationOptionsForAnimationCurve(7), animations: animations, completion: completion)
    }
    
    func presentAnimationForAlert(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        let coverView = createCoverView(container.bounds)
        container.addSubview(coverView)
        
        toView.frame = container.bounds
        toView.transform = fromView.transform.concatenating(CGAffineTransform(scaleX: 1.2, y: 1.2))
        coverView.addSubview(toView)

        transitionCoverView = coverView

        animation({
            toView.transform = fromView.transform
            coverView.alpha = 1
            }, completion: completion)
    }
    
    func dismissAnimationForAlert(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        transitionCoverView?.addSubview(fromView)
        
        animation({
            self.transitionCoverView?.alpha = 0
            self.transitionCoverView = nil
            }, completion: completion)
    }
    
    func presentAnimationForActionSheet(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        let coverView = createCoverView(container.bounds)
        container.addSubview(coverView)
        toView.frame = container.bounds
        container.addSubview(toView)
        
        backgroundViewBottomSpaceConstraint.constant = -toView.bounds.height
        backgroundViewTopSpaceConstraint.constant = toView.bounds.height
        view.layoutIfNeeded()
        contentView?.layoutIfNeeded()
        backgroundViewBottomSpaceConstraint.constant = 0
        backgroundViewTopSpaceConstraint.constant = 0
        
        transitionCoverView = coverView
        
        animation({
            self.view.layoutIfNeeded()
            coverView.alpha = 1
        }, completion: completion)
    }
    
    func dismissAnimationForActionSheet(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        container.addSubview(fromView)
        
        backgroundViewBottomSpaceConstraint.constant = -toView.bounds.height
        backgroundViewTopSpaceConstraint.constant = toView.bounds.height
        
        animation({
            self.view.layoutIfNeeded()
            self.transitionCoverView?.alpha = 0
            self.transitionCoverView = nil
        }, completion: completion)
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animateDuration()
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        
        guard let to = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) else {
            return transitionContext.completeTransition(false)
        }
        
        guard let from = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) else {
            return transitionContext.completeTransition(false)
        }
        
        if presentedAnimation == true {
            if preferredStyle == .alert {
                presentAnimationForAlert(container, toView: to.view, fromView: from.view) { _ in
                    transitionContext.completeTransition(true)
                }
            } else {
                presentAnimationForActionSheet(container, toView: to.view, fromView: from.view) { _ in
                    transitionContext.completeTransition(true)
                }
            }
        } else {
            if preferredStyle == .alert {
                dismissAnimationForAlert(container, toView: to.view, fromView: from.view) { _ in
                    transitionContext.completeTransition(true)
                }
            } else {
                dismissAnimationForActionSheet(container, toView: to.view, fromView: from.view) { _ in
                    transitionContext.completeTransition(true)
                }
            }
        }
    }
}
