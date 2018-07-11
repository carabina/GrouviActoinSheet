import Foundation
import UIKit

public struct ActionSheetTheme {
    static public let sideMargin: CGFloat = 10
    static public let topMargin: CGFloat = 24
    static public let cornerRadius: CGFloat = 10
}

public struct ItemActionTheme {

    static public let defaultItemHeight: CGFloat = 57
    static public let titleColor = UIColor(hex: 0x007AFF)
    static public let titleFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
    static public let boldTitleFont = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.semibold)
    static public let selectedBackground = UIColor(hex: 0xDBDDDB)
    static public let defaultBackground = UIColor.white

}

public struct TitleItemTheme {

    static let defaultItemHeight: CGFloat = 33
    static let titleColor = UIColor(hex: 0x828282)
    static let titleFont = UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.regular)
    static let topOffset: CGFloat = 8
    static let sideOffset: CGFloat = 8

}

