import UIKit
import os

// 放在类外面，定义全局的 CoreText 可识别的 Key
private let CTImageNameKey = "CTImageName" as CFString
private let CTImageSizeKey = "CTImageSize" as CFString
private let CTImageKey = "CTImage" as CFString

// 也可以用 NSAttributedString.Key 关联（兼容 UIKit）
extension NSAttributedString.Key {
    static let ctImageName = NSAttributedString.Key(rawValue: CTImageNameKey as String)
    static let ctImageSize = NSAttributedString.Key(rawValue: CTImageSizeKey as String)
    static let ctImage = NSAttributedString.Key(rawValue: CTImageKey as String)
}



class CoreTextLabel: UIView {
    // MARK: - Properties
    private var ctFrame: CTFrame?
    private var attributedString: NSMutableAttributedString = NSMutableAttributedString()
    private let renderQueue = DispatchQueue(label: "com.coretext.render", qos: .userInteractive)
//    private var isRendering = false
    
    // 文本容器设置
    var textContainerSize: CGSize = .zero
    private var currentViewWidth: CGFloat = 0
    
    // 图片相关
    private var imageInfos: [ImageInfo] = []
    
    // 用于 Auto Layout
    private var heightConstraint: NSLayoutConstraint?
    
    private var imagePlaceholders: [Int: (image: UIImage, size: CGSize)] = [:]
    
    private var _isRendering = false
    // 初始化不公平锁（OS_UNFAIR_LOCK_INIT 是常量）
    private var renderingLock = os_unfair_lock_s()
    
    // 原子性读写 isRendering
    private var isRendering: Bool {
        get {
            os_unfair_lock_lock(&renderingLock) // 加锁
            let value = _isRendering
            os_unfair_lock_unlock(&renderingLock) // 解锁
            return value
        }
        set {
            os_unfair_lock_lock(&renderingLock)
            _isRendering = newValue
            os_unfair_lock_unlock(&renderingLock)
        }
    }
    
    // 缓存待执行的文本更新任务
    private var _pendingTextUpdates: [(text: NSAttributedString, completion: ((CGSize) -> Void)?)] = []
    // 替换为 os_unfair_lock（iOS 10+ 推荐）
    private var pendingLock = os_unfair_lock_s()
    
    // 原子性访问待执行任务队列（封装读写逻辑）
    private var pendingTextUpdates: [(text: NSAttributedString, completion: ((CGSize) -> Void)?)] {
        get {
            os_unfair_lock_lock(&pendingLock)
            let value = _pendingTextUpdates
            os_unfair_lock_unlock(&pendingLock)
            return value
        }
        set {
            os_unfair_lock_lock(&pendingLock)
            _pendingTextUpdates = newValue
            os_unfair_lock_unlock(&pendingLock)
        }
    }
    // MARK: - 处理待执行任务队列
    private func processPendingTasks() {
        // 原子性读取并清空待执行队列（避免读写冲突）
        os_unfair_lock_lock(&pendingLock)
        let tasks = _pendingTextUpdates
        _pendingTextUpdates.removeAll()
        os_unfair_lock_unlock(&pendingLock)
        print("tasks count = \(tasks.count)")
        // 依次处理每个任务（串行执行，保证顺序）
        for task in tasks {
            processTextUpdate(newText: task.text, completion: task.completion)
        }
    }
    
    // MARK: - Image Info Struct
    private struct ImageInfo {
        let image: UIImage
        let frame: CGRect
        let attachmentIndex: Int
    }
    
    // MARK: - CTRunDelegate 工具（核心：给占位符设置宽度）
    private func createRunDelegate(for imageSize: CGSize) -> CTRunDelegate {
        // 1. 修复 dealloc 回调类型：参数为非可选 UnsafeMutableRawPointer
        let deallocCallback: @convention(c) (UnsafeMutableRawPointer) -> Void = { ref in
            // 直接使用 ref（非可选），无需判空（CoreText 内部保证传递合法指针）
            Unmanaged<NSValue>.fromOpaque(ref).release() // 释放绑定的 NSValue
        }
        
        // 2. 完整实现 CTRunDelegateCallbacks（所有回调参数类型匹配）
        var callbacks = CTRunDelegateCallbacks(
            version: kCTRunDelegateVersion1,
            dealloc: deallocCallback, // 现在类型完全匹配
            getAscent: { (ref: UnsafeMutableRawPointer) -> CGFloat in
                let sizeValue = Unmanaged<NSValue>.fromOpaque(ref).takeUnretainedValue()
                return sizeValue.cgSizeValue.height
            },
            getDescent: { (ref: UnsafeMutableRawPointer) -> CGFloat in
                return 0
            },
            getWidth: { (ref: UnsafeMutableRawPointer) -> CGFloat in
                let sizeValue = Unmanaged<NSValue>.fromOpaque(ref).takeUnretainedValue()
                return sizeValue.cgSizeValue.width
            }
        )
        
        // 3. 创建 delegate 并解包（断言兜底）
        let sizeValue = NSValue(cgSize: imageSize)
        guard let delegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(sizeValue).toOpaque()) else {
            assertionFailure("CTRunDelegate 创建失败，图片尺寸：\(imageSize)")
            let emptySize = NSValue(cgSize: .zero)
            return CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(emptySize).toOpaque())!
        }
        return delegate
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .clear
        contentMode = .redraw
        translatesAutoresizingMaskIntoConstraints = false
        updateViewWidth()
    }
    
    // MARK: - Public Methods
    func setAttributedText(_ text: NSAttributedString) {
        attributedString = NSMutableAttributedString(attributedString: text)
        setNeedsDisplay()
    }
    
    func appendAttributedText(_ text: NSAttributedString, completion: ((CGSize) -> Void)? = nil) {
        let copiedText = text.copy() as? NSAttributedString
        renderQueue.async { [weak self] in
            guard let self = self,let copiedText = copiedText,copiedText.length > 0 else { return }
            
            self.updateViewWidth()
            
            if !self.isRendering {
                self.processTextUpdate(newText: copiedText, completion: completion)
            }
        }
    }
    
    func clear() {
        attributedString = NSMutableAttributedString()
        ctFrame = nil
        imageInfos.removeAll()
        textContainerSize = .zero
        updateHeightConstraint()
        setNeedsDisplay()
    }
    
    // MARK: - Text Processing
    private func processTextUpdate(newText: NSAttributedString, completion: ((CGSize) -> Void)? = nil) {
        guard !isRendering else {
            os_unfair_lock_lock(&pendingLock)
            _pendingTextUpdates.append((newText, completion))
            os_unfair_lock_unlock(&pendingLock)
            return
        }
        isRendering = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 解析并处理富文本中的图片
            let processedText = self.processImagesInAttributedString(newText)
            self.attributedString = NSMutableAttributedString(attributedString: processedText)
            processedText.enumerateAttributes(in: NSRange(location: 0, length: processedText.length), options: []) { attrs, range, _ in
//                if let name = attrs[.ctImageName] as? String {
//                    print("测试j_1 绑定成功：位置\(range)，CTImageName=\(name)")
//                }
            }
            
            let rawString = processedText.string
//            for (i, char) in rawString.enumerated() {
//                if char == "\u{FFFC}" {
//                    print("测试j_1 占位符位置：\(i)")
//                }
//            }
            
            // 计算大小
            let newSize = self.calculateTextSize(width: self.currentViewWidth)
            self.textContainerSize = newSize
            
            // 创建 CTFrame
            self.createCTFrame(width: newSize.width)
            
            // 提取图片信息
            self.extractImageInfo(from: processedText)
            
            DispatchQueue.main.async {
                self.updateHeightConstraint()
                self.setNeedsDisplay()
                self.isRendering = false
                completion?(newSize)
            }
            self.processPendingTasks()
        }
    }
    
    // MARK: - Image Processing
    private func processImagesInAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        imagePlaceholders.removeAll()
        mutableString.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            if let attachment = value as? NSTextAttachment,
               let image = attachment.image {
                
                let placeholder = "\u{FFFC}"
                let imageSize = self.calculateImageSize(attachment)
                
                
                
                // 1. 获取原有属性，并移除 attachment
                var attributes = mutableString.attributes(at: range.location, effectiveRange: nil)
                attributes.removeValue(forKey: .attachment)
                
                let runDelegate = self.createRunDelegate(for: imageSize)
                attributes[NSAttributedString.Key(kCTRunDelegateAttributeName as String)] = runDelegate
                
                // 2. 设置行高/字体（原有逻辑不变）
                let font = UIFont.systemFont(ofSize: max(imageSize.height * 0.8, 1))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.maximumLineHeight = imageSize.height
                paragraphStyle.minimumLineHeight = imageSize.height
                attributes[.font] = font
                attributes[.paragraphStyle] = paragraphStyle
                
                // 3. 关键修复：用全局定义的 Key 设置自定义属性（兼容 CoreText）
                attributes[.ctImageName] = "image_\(range.location)" // 用扩展的 Key
                attributes[.ctImageSize] = NSValue(cgSize: imageSize)
                attributes[.ctImage] = image
                
                // 4. 替换占位符（原有逻辑不变）
                let placeholderString = NSAttributedString(string: placeholder, attributes: attributes)
                mutableString.replaceCharacters(in: range, with: placeholderString)
                
                imagePlaceholders[range.location] = (image, imageSize)
            }
        }
        return mutableString
    }
    
    private func extractImageInfo(from attributedString: NSAttributedString) {
        
        imageInfos.removeAll()
//        print("测试j_1 textContainerSize = \(textContainerSize)")
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: textContainerSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineCount = lines.count
        if lineCount == 0 { return }
        
        var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lineCount), &lineOrigins)
        
        var currentIndex = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let lineOrigin = lineOrigins[lineIndex]
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            
            for run in runs {
                let runAttributes = CTRunGetAttributes(run) as! [CFString: Any] // 关键：Key 类型改为 CFString
                let runRange = CTRunGetStringRange(run)
                let startIndex = runRange.location
                let endIndex = runRange.location + runRange.length
                // 检查当前 run 是否包含图片占位符
                for index in startIndex..<endIndex {
                    guard let (image, imageSize) = imagePlaceholders[index] else { continue }
                    // 计算图片位置（原有逻辑）
                        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
                        let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(index - startIndex, 1), &ascent, &descent, &leading))
                        
                        var runOrigin = CGPoint.zero
                        CTRunGetPositions(run, CFRangeMake(index - startIndex, 1), &runOrigin)
                        
                        let imageRect = CGRect(
                            x: lineOrigin.x + runOrigin.x,
                            y: lineOrigin.y - descent,
                            width: imageSize.width,
                            height: imageSize.height
                        )
                        
                        let uiKitY = textContainerSize.height - imageRect.origin.y - imageSize.height
                        let transformedRect = CGRect(
                            x: imageRect.origin.x,
                            y: uiKitY,
                            width: imageSize.width,
                            height: imageSize.height
                        )
                        
                        imageInfos.append(ImageInfo(
                            image: image,
                            frame: transformedRect,
                            attachmentIndex: index
                        ))
                }
            }
        }
    }
    
    private func calculateImageSize(_ attachment: NSTextAttachment) -> CGSize {
        var imageSize = CGSize.zero
        
        if let image = attachment.image {
            // 使用附件中的图片大小
            imageSize = image.size
            
            // 如果有自定义 bounds，使用它
            if !attachment.bounds.isEmpty {
                imageSize = attachment.bounds.size
            }
            
            // 确保图片不会太宽
            let maxWidth = UIScreen.main.bounds.width
            if imageSize.width > maxWidth {
                let scale = maxWidth / imageSize.width
                imageSize = CGSize(width: maxWidth, height: imageSize.height * scale)
            }
            
            // 设置最小高度
            if imageSize.height < 1 {
                imageSize.height = 1
            }
        }
        
        return imageSize
    }
    
    // MARK: - CoreText Methods
    private func createCTFrame(width: CGFloat) {
        guard attributedString.length > 0 else {
            ctFrame = nil
            return
        }
        
        let validWidth = max(width, 10)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: textContainerSize), transform: nil)
        
        ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
    }
    
    private func calculateTextSize(width: CGFloat) -> CGSize {
        guard attributedString.length > 0 else {
            return .zero
        }
        
        let validWidth = max(width, 10)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let constraintSize = CGSize(width: validWidth, height: .greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attributedString.length),
            nil,
            constraintSize,
            nil
        )
        
//        print("calculateTextSize = \(suggestedSize)")
        return CGSize(width: ceil(suggestedSize.width), height: ceil(suggestedSize.height))
    }
    
    // MARK: - Layout
    private func updateViewWidth() {
        
        if Thread.isMainThread {
            currentViewWidth = bounds.width
        } else {
            DispatchQueue.main.sync {
                currentViewWidth = bounds.width
            }
        }
    }
    
    private func updateHeightConstraint() {
        if let heightConstraint = heightConstraint {
            heightConstraint.constant = max(textContainerSize.height, 1)
        } else {
            heightConstraint = heightAnchor.constraint(equalToConstant: max(textContainerSize.height, 1))
            heightConstraint?.isActive = true
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let oldWidth = currentViewWidth
        currentViewWidth = bounds.width
        if abs(oldWidth - currentViewWidth) > 0.1 && attributedString.length > 0 {
            textContainerSize = calculateTextSize(width: currentViewWidth)
            createCTFrame(width: currentViewWidth)
            extractImageInfo(from: attributedString)
            updateHeightConstraint()
            setNeedsDisplay()
        }
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let frame = ctFrame else {
            return
        }
        
        // 保存上下文状态
        context.saveGState()
        
        // 清空背景
        backgroundColor?.setFill()
        context.fill(rect)
        
        // 翻转坐标系（CoreText 使用不同的坐标系）
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 绘制文本
        CTFrameDraw(frame, context)
        
        // 恢复上下文状态（回到 UIKit 坐标系）
        context.restoreGState()
        
        // 绘制图片
        drawImages()
    }
    
    private func drawImages() {
        for imageInfo in imageInfos {
            // 在 UIKit 坐标系中绘制图片
            imageInfo.image.draw(in: imageInfo.frame)
        }
    }
    
    // MARK: - Helper Methods for Testing
    func addTestImage() {
        // 测试方法：添加一个图片到富文本中
        let mutableString = NSMutableAttributedString()
        
        // 添加文本
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        mutableString.append(NSAttributedString(string: "这是一行带有图片的文本", attributes: textAttributes))
        
        // 创建测试图片1
        UIGraphicsBeginImageContext(CGSize(width: 40, height: 40))
        UIColor.red.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 40, height: 40)).fill()
        let redImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let image1 = redImage {
            let attachment1 = NSTextAttachment()
            attachment1.image = image1
            // 设置图片与文本的对齐方式
            attachment1.bounds = CGRect(x: 0, y: -5, width: 40, height: 40)
            
            let imageString1 = NSAttributedString(attachment: attachment1)
            mutableString.append(imageString1)
            
            // 在图片后面继续添加文本
            mutableString.append(NSAttributedString(string: "，这是同一行的后续文本。", attributes: textAttributes))
            
            // 添加换行
            mutableString.append(NSAttributedString(string: "\n\n下一行：", attributes: textAttributes))
            
            // 创建测试图片2
            UIGraphicsBeginImageContext(CGSize(width: 30, height: 30))
            UIColor.blue.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 30, height: 30)).fill()
            let blueImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let image2 = blueImage {
                let attachment2 = NSTextAttachment()
                attachment2.image = image2
                attachment2.bounds = CGRect(x: 0, y: -3, width: 30, height: 30)
                
                let imageString2 = NSAttributedString(attachment: attachment2)
                mutableString.append(imageString2)
                
                mutableString.append(NSAttributedString(string: " 这是一张蓝色圆形图片。", attributes: textAttributes))
            }
        }
        
        // 设置文本
        self.setAttributedText(mutableString)
    }
    
    func addMultipleImagesInOneLine() {
        clear()
        
        let mutableString = NSMutableAttributedString()
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        
        mutableString.append(NSAttributedString(string: "同一行多个图片：", attributes: textAttributes))
        
        // 添加多个图片
        let colors: [UIColor] = [.red, .green, .blue, .orange, .purple]
        
        for (index, color) in colors.enumerated() {
            UIGraphicsBeginImageContext(CGSize(width: 25, height: 25))
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 25, height: 25), cornerRadius: 5).fill()
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let image = colorImage {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -4, width: 25, height: 25)
                
                let imageString = NSAttributedString(attachment: attachment)
                mutableString.append(imageString)
                
                // 在图片之间添加空格
                if index < colors.count - 1 {
                    mutableString.append(NSAttributedString(string: " ", attributes: textAttributes))
                }
            }
        }
        
        mutableString.append(NSAttributedString(string: " 这些是彩色方块。", attributes: textAttributes))
        
        self.setAttributedText(mutableString)
    }
}



extension String {

    public var length: Int {
        return count
    }

    public subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    public func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    public func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    public subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
