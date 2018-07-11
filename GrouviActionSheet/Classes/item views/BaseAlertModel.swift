import UIKit
import GrouviExtensions
import RxSwift

open class BaseAlertModel {

    public var showFullLandscape = true

    public var ignoreKeyboard = true
    public var hideInBackground = true

    public let disposeBag = DisposeBag()

    public var items = [BaseActionItem]()
    public var modelLayoutSubviews: (() -> ())?

    public var reload: (() -> ())?
    public var dismiss: ((Bool) -> ())?  // true - if success programmatically dismiss

    var contentHeight: CGFloat = 0

    open var cancelButtonTitle: String { return "Cancel" }

    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onBackgroundChanged), name: .UIApplicationDidEnterBackground, object: nil)
    }

    @objc open func onBackgroundChanged() {
        if hideInBackground {
            dismiss?(true)
        }
    }

    open func addItemView(_ item: BaseActionItem) {
        items.append(item)
    }

    func getItemViews() -> [BaseActionItem] {
        return items
    }

    func checkItems(forContentHeight: CGFloat) {
    }

    public func updateItems() {
        updateItems(forContentHeight: contentHeight)
    }

    func updateItems(forContentHeight height: CGFloat) {
        contentHeight = height

        let minimumHeight: CGFloat = items.filter { $0.required && !$0.hidden }.reduce(0, { sum, item in
            if sum + item.height > contentHeight {
                _ = item.changeHeight(for: contentHeight - sum)
            }
            return sum + item.height
        })
        let editableActions = items.filter { !$0.required && !$0.hidden }
        if minimumHeight < height {
            var usableHeight = height - minimumHeight
            editableActions.sorted().forEach { item in
                if usableHeight >= item.height, !item.hidden {
                    usableHeight -= item.height
                    item.showState = true
                } else {
                    if item.changeHeight(for: usableHeight) {
                        usableHeight -= item.height
                        item.showState = true
                    } else {
                        item.showState = false
                    }
                }
             }
        } else {
            editableActions.forEach { $0.showState = false }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
