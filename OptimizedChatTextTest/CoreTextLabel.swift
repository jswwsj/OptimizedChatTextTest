import UIKit

class CoreTextLabel: UIView {
    // MARK: - Properties
    private var ctFrame: CTFrame?
    private var attributedString: NSMutableAttributedString = NSMutableAttributedString()
    private let renderQueue = DispatchQueue(label: "com.coretext.render", qos: .userInteractive)
    private var isRendering = false
    
    // 文本容器设置
    var textContainerSize: CGSize = .zero
    private var currentViewWidth: CGFloat = 0
    
    // 图片相关
    private var imageInfos: [ImageInfo] = []
    
    // 用于 Auto Layout
    private var heightConstraint: NSLayoutConstraint?
    
    // MARK: - Image Info Struct
    private struct ImageInfo {
        let image: UIImage
        let frame: CGRect
        let attachmentIndex: Int
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
        guard !isRendering else { return }
        isRendering = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            print("log_j processTextUpdate")
            // 解析并处理富文本中的图片
            let processedText = self.processImagesInAttributedString(newText)
            self.attributedString = NSMutableAttributedString(attributedString: processedText)
            
            // 计算大小
            let newSize = self.calculateTextSize(width: self.currentViewWidth)
            self.textContainerSize = newSize
            print("CoreTextLabel newText.length = \(newText.length) newsize.width = \(newSize.width) newsize.height = \(newSize.height)")
            // 创建 CTFrame
            self.createCTFrame(width: self.currentViewWidth)
            
            // 提取图片信息
            self.extractImageInfo(from: processedText)
            
            DispatchQueue.main.async {
                self.updateHeightConstraint()
                self.setNeedsDisplay()
                self.isRendering = false
                completion?(newSize)
            }
        }
    }
    
    // MARK: - Image Processing
    private func processImagesInAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        mutableString.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            if let attachment = value as? NSTextAttachment,
               let image = attachment.image {
                
                // 创建图片占位符
                let placeholder = "\u{FFFC}"  // Unicode 对象替换字符
                
                // 计算图片尺寸
                let imageSize = self.calculateImageSize(attachment)
                
                // 创建图片占位符的属性
                var attributes = mutableString.attributes(at: range.location, effectiveRange: nil)
                
                // 创建新的字体，设置行高与图片高度一致
                let font = UIFont.systemFont(ofSize: 0)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.maximumLineHeight = imageSize.height
                paragraphStyle.minimumLineHeight = imageSize.height
                
                attributes[.font] = font
                attributes[.paragraphStyle] = paragraphStyle
                
                // 存储图片信息
                attributes[.init("CTImageName")] = "image_\(range.location)"
                attributes[.init("CTImageSize")] = NSValue(cgSize: imageSize)
                attributes[.init("CTImage")] = image
                
                // 替换为图片占位符
                let placeholderString = NSAttributedString(string: placeholder, attributes: attributes)
                mutableString.replaceCharacters(in: range, with: placeholderString)
            }
        }
        
        return mutableString
    }
    
    private func extractImageInfo(from attributedString: NSAttributedString) {
        imageInfos.removeAll()
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: CGRect(origin: .zero, size: textContainerSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        
        // 获取行数组
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineCount = lines.count
        
        if lineCount == 0 { return }
        
        // 获取每行的原点
        var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lineCount), &lineOrigins)
        
        var currentIndex = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let lineOrigin = lineOrigins[lineIndex]
            
            // 获取当前行的 run 数组
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            
            for run in runs {
                let runRange = CTRunGetStringRange(run)
                let runAttributes = CTRunGetAttributes(run) as! [String: Any]
                
                // 检查是否为图片占位符
                if runAttributes["CTImageName"] != nil,
                   let imageSizeValue = runAttributes["CTImageSize"] as? NSValue,
                   let image = runAttributes["CTImage"] as? UIImage {
                    
                    // 计算 run 的位置 - 修正这里
                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    var leading: CGFloat = 0
                    let width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading))
                    
                    // 获取 run 的起点 - 使用正确的 CGPoint 类型
                    var runOrigin = CGPoint.zero
                    CTRunGetPositions(run, CFRangeMake(0, 1), &runOrigin)
                    
                    // 计算图片的实际绘制位置（CoreText 坐标系）
                    let imageSize = imageSizeValue.cgSizeValue
                    let imageRect = CGRect(
                        x: lineOrigin.x + runOrigin.x,
                        y: lineOrigin.y - descent,
                        width: imageSize.width,
                        height: imageSize.height
                    )
                    
                    // 将坐标转换为 UIKit 坐标系
                    let transformedRect = CGRect(
                        x: imageRect.origin.x,
                        y: bounds.height - imageRect.origin.y - imageSize.height,
                        width: imageSize.width,
                        height: imageSize.height
                    )
                    
                    let imageInfo = ImageInfo(
                        image: image,
                        frame: transformedRect,
                        attachmentIndex: currentIndex
                    )
                    imageInfos.append(imageInfo)
                    currentIndex += 1
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
            let maxWidth = currentViewWidth - 30 // 减去边距
            if imageSize.width > maxWidth {
                let scale = maxWidth / imageSize.width
                imageSize = CGSize(width: maxWidth, height: imageSize.height * scale)
            }
            
            // 设置最小高度
            if imageSize.height < 1 {
                imageSize.height = 20
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
            heightConstraint.constant = max(textContainerSize.height, 50)
        } else {
            heightConstraint = heightAnchor.constraint(equalToConstant: max(textContainerSize.height, 1))
            heightConstraint?.isActive = true
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        currentViewWidth = bounds.width
        print("CoreTextLabel bounds.width=\(bounds.width) bounds.height=\(bounds.height) attr.length = \(attributedString.length)")
        if attributedString.length > 0 {
            textContainerSize = calculateTextSize(width: currentViewWidth)
            createCTFrame(width: currentViewWidth)
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
        print("log_j draw")
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
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        mutableString.append(NSAttributedString(string: "测试图片: ", attributes: textAttributes))
        
        // 创建测试图片
        UIGraphicsBeginImageContext(CGSize(width: 50, height: 50))
        UIColor.blue.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 50, height: 50)).fill()
        let testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let image = testImage {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -10, width: 50, height: 50) // y偏移可以让图片对齐
            
            let imageString = NSAttributedString(attachment: attachment)
            mutableString.append(imageString)
            
            // 添加更多文本
            mutableString.append(NSAttributedString(string: " 这是一张测试图片。", attributes: textAttributes))
            
            // 添加到标签
            self.appendAttributedText(mutableString) { newSize in
                print("图片添加完成，新尺寸: \(newSize)")
            }
        }
    }
}
