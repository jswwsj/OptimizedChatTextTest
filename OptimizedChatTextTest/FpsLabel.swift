//
//  FpsLabel.swift
//  tableViewSwiftTest
//
//  Created by jiangsiwei on 2025/7/3.
//
#if DEBUG
import UIKit

class FPSLabel: UILabel {
    private let kSize = CGSize(width: 55, height: 20)
    
    private var link: CADisplayLink?
    private var count: UInt = 0
    private var lastTime: TimeInterval = 0
    private var mainFont: UIFont  // 重命名为 mainFont 避免冲突
    private var subFont: UIFont
    public var fpsCount: CGFloat = 0
    
    override init(frame: CGRect) {
        let initialFrame = frame.size == .zero ? CGRect(origin: frame.origin, size: kSize) : frame
        
        // 设置字体
        if let menloFont = UIFont(name: "Menlo", size: 14) {
            mainFont = menloFont
            subFont = UIFont(name: "Menlo", size: 4) ?? menloFont
        } else {
            let courierFont = UIFont(name: "Courier", size: 14) ?? UIFont.systemFont(ofSize: 14)
            mainFont = courierFont
            subFont = UIFont(name: "Courier", size: 4) ?? courierFont
        }
        
        super.init(frame: initialFrame)
        
        layer.cornerRadius = 5
        clipsToBounds = true
        textAlignment = .center
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        // 设置初始字体
        font = mainFont
        
        // 设置 CADisplayLink
        link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        link?.invalidate()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return kSize
    }
    
    @objc private func tick(_ link: CADisplayLink) {
        if lastTime == 0 {
            lastTime = link.timestamp
            return
        }
        
        count += 1
        let delta = link.timestamp - lastTime
        if delta < 1 { return }
        
        lastTime = link.timestamp
        let fps = Double(count) / delta
        count = 0
        
        let progress = fps / 60.0
        let color = UIColor(hue: CGFloat(0.27 * (progress - 0.2)), saturation: 1, brightness: 0.9, alpha: 1)
        fpsCount = fps
        let fpsText = String(format: "%d FPS", Int(round(fps)))
        let attributedText = NSMutableAttributedString(string: fpsText)
        
        // 设置字体和颜色
        let fullRange = NSRange(location: 0, length: attributedText.length)
        let fpsValueRange = NSRange(location: 0, length: attributedText.length - 3)
        let fpsUnitRange = NSRange(location: attributedText.length - 3, length: 3)
        let smallPRange = NSRange(location: attributedText.length - 4, length: 1)
        
        attributedText.addAttribute(.font, value: mainFont, range: fullRange)
        attributedText.addAttribute(.foregroundColor, value: color, range: fpsValueRange)
        attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: fpsUnitRange)
        attributedText.addAttribute(.font, value: subFont, range: smallPRange)
        
        self.attributedText = attributedText
    }
}
#endif
