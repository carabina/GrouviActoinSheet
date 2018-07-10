import UIKit
import GrouviExtensionKit

public class ActionSheetAnimation: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {

    var presentedAnimation = false
    public weak var controller: ActionSheetController?

    static let animateDuration: TimeInterval = 0.35
    let coverColor = UIColor.black.withAlphaComponent(0.7)

    public override init() {
        fatalError("Deprecated init!")
    }

    public init(withController controller: ActionSheetController) {
        self.controller = controller

        super.init()
        controller.transitioningDelegate = self
    }

    static func animationOptionsForAnimationCurve(_ curve: UInt) -> UIViewAnimationOptions {
        return UIViewAnimationOptions(rawValue: curve << 16)
    }

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return ActionSheetAnimation.animateDuration
    }

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedAnimation = true
        return self
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedAnimation = false
        return self
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
            presentAnimationForActionSheet(container, toView: to.view, fromView: from.view) { _ in
                self.controller?.showedController = true
                transitionContext.completeTransition(true)
            }
        } else {
            dismissAnimationForActionSheet(container, toView: to.view, fromView: from.view) { _ in
                transitionContext.completeTransition(true)
            }
        }
    }

    func createCoverView(_ frame: CGRect) -> UIView {
        let coverView = UIView(frame: frame)

        coverView.backgroundColor = self.coverColor
        coverView.alpha = 0
        coverView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return coverView
    }

    static public func animation(_ animations: @escaping () -> Void) {
        ActionSheetAnimation.animation(animations, completion: nil)
    }

    static public func animation(_ animations: @escaping () -> Void, completion: ((Bool) -> Void)?) {
        UIView.animate(withDuration: 0.35, delay: 0, options: animationOptionsForAnimationCurve(5), animations: animations, completion: completion)
    }

    func presentAnimationForActionSheet(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        controller?.coverView = createCoverView(container.bounds)
        if let coverView = controller?.coverView {
            container.addSubview(coverView)
        }

        toView.frame = container.bounds
        controller?.coverView?.addSubview(toView)

        setVisibleViews(true)

        ActionSheetAnimation.animation({ [weak self] in
            self?.controller?.coverView?.alpha = 1
            self?.controller?.view.layoutIfNeeded()
        }, completion: completion)
    }

    func dismissAnimationForActionSheet(_ container: UIView, toView: UIView, fromView: UIView, completion: @escaping (Bool) -> Void) {
        container.addSubview(fromView)
        setVisibleViews(false)

        ActionSheetAnimation.animation({ [weak self] in
            self?.controller?.coverView?.alpha = 0
            self?.controller?.view.layoutIfNeeded()
        }, completion: completion)
    }

    func setVisibleViews(_ visible: Bool) {
        if let height = controller?.view.frame.height {
            controller?.backgroundView.snp.updateConstraints { maker in
                maker.top.bottom.equalToSuperview().offset( visible ? 0 : height)
            }
        }
    }

}
