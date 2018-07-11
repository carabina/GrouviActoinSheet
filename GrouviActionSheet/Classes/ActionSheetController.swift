import Foundation
import GrouviExtensionKit
import SnapKit

public enum ActionStyle: Int { case alert, sheet }

public class ActionSheetController: UIViewController, UIScrollViewDelegate {

    var actionSheetAnimation: ActionSheetAnimation?
    var showedController: Bool = false
    var window: UIWindow?

    var coverView: UIView?
    var marginView = UIView()
    var backgroundView = RespondView()

    open var contentBackgroundColor: UIColor? {
        didSet {
            contentView.backgroundColor = contentBackgroundColor
            dismissView.backgroundColor = contentBackgroundColor
        }
    }
    var contentView = UIView()
    var contentViewWillChangeHeight: ((CGFloat) -> (CGFloat))?

    public var onDismiss: ((Bool) -> ())? // true - if dismiss programmatically after done

    public var model: BaseAlertModel
    var actionStyle: ActionStyle

    var itemsScrollView = ItemsScrollView(frame: CGRect.zero)

    var dismissView = UIView()
    var cancelButtonTitle: String
    var dismissItemView: ActionItemView?

    var inTransitioning = false

    var isHiddenDismiss = false
    var keyboardHeight: CGFloat?
    var hideDismissOnKeyboardOpen = true
    public var hideDismissInLandScapeMode = false

    fileprivate var originalCenter = CGPoint.zero
    var panGestureRecognizer: UIPanGestureRecognizer?

    public required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    public init(withModel model: BaseAlertModel = BaseAlertModel(), actionStyle: ActionStyle = .sheet, customCancelButtonTitle: String? = nil) {

        self.model = model
        self.actionStyle = actionStyle
        self.cancelButtonTitle = customCancelButtonTitle ?? model.cancelButtonTitle
        super.init(nibName: nil, bundle: nil)

        model.reload = { [weak self] in
            self?.layoutContentView()
        }
        model.dismiss = { [weak self] successfulState in
            self?.dismiss(state: successfulState)
        }
        commonInit()
    }

    func commonInit() {

        actionSheetAnimation = ActionSheetAnimation(withController: self)

        modalPresentationStyle = .custom
        modalTransitionStyle = .crossDissolve

        initViews()
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        view.addGestureRecognizer(panGestureRecognizer!)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func initViews() {

        // full screen view, witch moving to/from screen
        view.addSubview(backgroundView)

        let height = view.frame.height
        backgroundView.snp.makeConstraints { maker in
            maker.top.bottom.equalToSuperview().offset(height)
            maker.leading.trailing.equalToSuperview()
        }
        backgroundView.addSubview(marginView)
        backgroundView.touchHandler = { [weak self] _ in
            self?.dismiss()
        }

        // view with margin contains content
        if model.showFullLandscape {
            marginView.snp.makeConstraints { maker in
                maker.top.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(ActionSheetTheme.topMargin)
                maker.bottom.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(-ActionSheetTheme.sideMargin)
                maker.leading.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(ActionSheetTheme.sideMargin)
                maker.trailing.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(-ActionSheetTheme.sideMargin)
            }
        } else {
            let size = UIScreen.main.bounds.size
            let maximumWidth = min(size.width, size.height) - 2 * ActionSheetTheme.sideMargin

            marginView.snp.makeConstraints { maker in
                maker.top.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(ActionSheetTheme.topMargin)
                maker.bottom.equalTo(LayoutHelper.instance.safeGuides(for: backgroundView)).offset(-ActionSheetTheme.sideMargin)
                maker.centerX.equalToSuperview()
                maker.width.equalTo(maximumWidth)
            }
        }
        // cancel button
        if actionStyle == .sheet {
            dismissItemView = ActionItemView(item: ActionItem(title: cancelButtonTitle, bold: true, tag: -1, hidden: false, required: true))
            marginView.addSubview(dismissView)
            dismissView.backgroundColor = ItemActionTheme.defaultBackground
            dismissView.layer.cornerRadius = ActionSheetTheme.cornerRadius
            dismissView.clipsToBounds = true
            dismissView.snp.makeConstraints { maker in
                maker.leading.trailing.bottom.equalToSuperview()
                maker.height.equalTo(ItemActionTheme.defaultItemHeight)
            }
            dismissView.addSubview(dismissItemView!)
            dismissItemView?.snp.makeConstraints { maker in
                maker.edges.equalToSuperview()
            }
            dismissItemView?.item?.action = { [weak self] _ in
                self?.dismiss()
            }
        }
        // content view
        initContentView()

        view.layoutIfNeeded()
    }

    func initContentView() {
        marginView.addSubview(contentView)
        contentView.backgroundColor = contentBackgroundColor ?? UIColor.white
        contentView.layer.cornerRadius = ActionSheetTheme.cornerRadius
        contentView.clipsToBounds = true
        contentView.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview()
            if actionStyle == .sheet {
                maker.bottom.equalTo(dismissView.snp.top).offset(-ActionSheetTheme.sideMargin)
            } else {
                maker.centerY.equalToSuperview()
            }
            maker.height.equalTo(0)
        }
        contentViewWillChangeHeight = { [weak self] maxHeight in
            return self?.changeContentView(maxHeight: maxHeight) ?? 0
        }

        contentView.addSubview(itemsScrollView)
        itemsScrollView.snp.makeConstraints { maker in
            maker.leading.trailing.bottom.equalToSuperview()
            maker.height.equalToSuperview()
        }
        itemsScrollView.delegate = self

        let width = model.showFullLandscape ? UIScreen.main.bounds.width : min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        itemsScrollView.initialSetFrame(width: width - 2 * ActionSheetTheme.sideMargin)

        model.getItemViews().forEach { item in
            itemsScrollView.addItem(item)
        }
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if hideDismissInLandScapeMode {
            hideDismissView(view.frame.size.width > view.frame.size.height)
        }
    }

    open func addItemView(_ item: BaseActionItem) {
        itemsScrollView.addItem(item)
        model.addItemView(item)
    }

    func changeContentView(maxHeight: CGFloat) -> CGFloat {
        model.checkItems(forContentHeight: maxHeight)
        model.updateItems(forContentHeight: maxHeight)
        itemsScrollView.reload()

        return itemsScrollView.contentSize.height
    }


    func hideDismissView(_ hide: Bool) {
        isHiddenDismiss = hide
        dismissView.isHidden = hide
        // remove.show dismissView
        if actionStyle == .sheet {
            dismissView.snp.updateConstraints() { maker in
                maker.bottom.equalToSuperview().offset(isHiddenDismiss ? (ItemActionTheme.defaultItemHeight + ActionSheetTheme.sideMargin) : 0)
            }
        }
    }

    func hideKeyboard() {
        view.endEditing(true)
    }

    // Rotate screen and change sizes

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        inTransitioning = true
        if hideDismissInLandScapeMode {
            hideDismissView(size.width > size.height)
        }

        coordinator.animate(alongsideTransition: { context in
            self.coverView?.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.inTransitioning = false
        })
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        backgroundView.layoutIfNeeded()
        layoutContentView()
    }

    func layoutContentView() {

        model.modelLayoutSubviews?()

        let maximumHeight = marginView.bounds.height - (isHiddenDismiss || actionStyle == .alert ? 0 : (dismissView.bounds.height + ActionSheetTheme.sideMargin))
        let itemsContentHeight = contentViewWillChangeHeight?(maximumHeight) ?? itemsScrollView.contentSize.height

        let newHeight = max(0, min(maximumHeight, itemsContentHeight))

        contentView.snp.updateConstraints { maker in
            maker.height.equalTo(newHeight)
        }

        ActionSheetAnimation.animation({
            self.view.layoutIfNeeded()
        })
    }

    // Pan Handling

    @objc func handlePanGesture(gesture: UIPanGestureRecognizer) {
        switch (gesture.state) {
        case .began:
            originalCenter = marginView.center
            break
        case .ended:
            let velocity = gesture.velocity(in: view)
            if velocity.y < 100 {
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

    public func show(fromController: UIViewController? = nil) {
        let window: UIWindow
        if fromController != nil, let keyWindow = UIApplication.shared.keyWindow {
            fromController?.view.endEditing(true)
            window = keyWindow
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            UIApplication.shared.sendAction(#selector(resignFirstResponder), to: nil, from: nil, for: nil)

            window.rootViewController = UIViewController()
            window.isHidden = false
            window.rootViewController?.present(self, animated: true, completion: nil)
        }
        fromController?.present(self, animated: true)
    }

    // ItemsScrollView delegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView.bounds.height + scrollView.contentOffset.y) > scrollView.contentSize.height {
            scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height), animated: false)
        } else if scrollView.contentOffset.y < 0 {
            scrollView.setContentOffset(CGPoint.zero, animated: false)
        }
    }

    // keyboard Observer

    @objc func keyboardWillHide(_ notification: Notification) {
        // TODO: Normally observe keyboard with accessoryView
        if !model.ignoreKeyboard, !inTransitioning {
            keyboardHeight = nil

            actionSheetAnimation?.setVisibleViews(showedController)

            if hideDismissOnKeyboardOpen {
                hideDismissView(false)
            }

            ActionSheetAnimation.animation({
                self.view.layoutIfNeeded()
            })
        }
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        // TODO: Normally observe keyboard with accessoryView

        if !model.ignoreKeyboard, let window = view.window {
            if let frame = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue {
                let rect = window.convert(frame, to: view)

                let beginFrame = ((notification as NSNotification).userInfo?[UIKeyboardFrameBeginUserInfoKey] as AnyObject) as? CGRect
                let endFrame = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject) as? CGRect

                // Return early if the keyboard's frame isn't changing.
                if let beginFrame = beginFrame, let endFrame = endFrame, beginFrame.origin.equalTo(endFrame.origin) {
                    return
                }

                keyboardHeight = rect.height
                //align alert to keyboard size. Trouble with accessoryViews
                backgroundView.snp.updateConstraints { maker in
                    maker.bottom.equalToSuperview().offset(rect.origin.y - view.bounds.size.height)
                }
                if hideDismissOnKeyboardOpen {
                    hideDismissView(true)
                }

                ActionSheetAnimation.animation({
                    self.view.layoutIfNeeded()
                })
            }
        }
    }

    open func dismiss(state: Bool = false) {
        dismiss(animated: true, completion: { [weak self] in
            self?.onDismiss?(state)
        })
        window = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
