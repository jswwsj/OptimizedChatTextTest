// YYTextMainView.swift
import UIKit

class YYTextMainView: UIView {
    
    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var textView: YYTextView! // YYTextView 实例
    private var scrollToBottomButton: UIButton!
    private var autoScrollSwitch: UISwitch!
    private var autoScrollLabel: UILabel!
    private var monitorLabel: UILabel!
    private var controlPanel: UIView!
    
    // MARK: - Properties
    private var timer: Timer?
    private var updateCount = 0
    private var shouldAutoScroll = true
    private var isScrolling = false
    private var coreTextStr: NSMutableAttributedString = NSMutableAttributedString()
    public var completion: ((_ length: Int) -> Void)? = nil
    private let timeNumber: TimeInterval = 0.1 // 补充缺失的定时器间隔
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .white
        
        setupScrollView()
        setupTextView()
        setupControlPanel()
        
        // 添加初始文本
        let initialText = createAttributedString("原生 Auto Layout 示例\n\n", color: .systemBlue)
        coreTextStr.append(initialText)
        textView.attributedText = coreTextStr
        
        // 启动定时器
        startTimer()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .systemGray6
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)
        
        // Content View
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -150),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupTextView() {
        textView = YYTextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .white
        textView.isEditable = false // 禁止编辑
        textView.isSelectable = true // 允许选择文本
        textView.isScrollEnabled = false // YYTextView 禁用自身滚动的正确属性
        
        // 修复：YYTextView 移除左右边距的正确方式
        textView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0) // 重置内容内边距
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15) // 仅保留左右15的内边距
        
        
        contentView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
    }
    
    private func setupControlPanel() {
        controlPanel = UIView()
        controlPanel.translatesAutoresizingMaskIntoConstraints = false
        controlPanel.backgroundColor = .systemGray5
        controlPanel.layer.cornerRadius = 8
        addSubview(controlPanel)
        
        NSLayoutConstraint.activate([
            controlPanel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            controlPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            controlPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            controlPanel.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        setupControlButtons()
    }
    
    private func setupControlButtons() {
        // 滚动到底部按钮
        scrollToBottomButton = UIButton(type: .system)
        scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
        scrollToBottomButton.setTitle("滚动到底部", for: .normal)
        scrollToBottomButton.backgroundColor = .systemBlue
        scrollToBottomButton.setTitleColor(.white, for: .normal)
        scrollToBottomButton.layer.cornerRadius = 6
        scrollToBottomButton.addTarget(self, action: #selector(scrollToBottom), for: .touchUpInside)
        controlPanel.addSubview(scrollToBottomButton)
        
        // 清除按钮
        let clearButton = UIButton(type: .system)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setTitle("清除文本", for: .normal)
        clearButton.backgroundColor = .systemRed
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.layer.cornerRadius = 6
        clearButton.addTarget(self, action: #selector(clearText), for: .touchUpInside)
        controlPanel.addSubview(clearButton)
        
        // 自动滚动开关
        autoScrollSwitch = UISwitch()
        autoScrollSwitch.translatesAutoresizingMaskIntoConstraints = false
        autoScrollSwitch.isOn = true
        autoScrollSwitch.addTarget(self, action: #selector(autoScrollChanged), for: .valueChanged)
        controlPanel.addSubview(autoScrollSwitch)
        
        // 自动滚动标签
        autoScrollLabel = UILabel()
        autoScrollLabel.translatesAutoresizingMaskIntoConstraints = false
        autoScrollLabel.text = "自动滚动到底部"
        autoScrollLabel.font = UIFont.systemFont(ofSize: 14)
        controlPanel.addSubview(autoScrollLabel)
        
        // 暂停/继续按钮
        let pauseButton = UIButton(type: .system)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.setTitle("暂停更新", for: .normal)
        pauseButton.setTitle("继续更新", for: .selected)
        pauseButton.backgroundColor = .systemOrange
        pauseButton.setTitleColor(.white, for: .normal)
        pauseButton.layer.cornerRadius = 6
        pauseButton.addTarget(self, action: #selector(toggleTimer), for: .touchUpInside)
        controlPanel.addSubview(pauseButton)
        
        // 性能监控标签
        monitorLabel = UILabel()
        monitorLabel.translatesAutoresizingMaskIntoConstraints = false
        monitorLabel.text = "更新次数: 0"
        monitorLabel.textAlignment = .center
        monitorLabel.font = UIFont.systemFont(ofSize: 12)
        monitorLabel.textColor = .darkGray
        addSubview(monitorLabel)
        
        // 约束
        NSLayoutConstraint.activate([
            scrollToBottomButton.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 15),
            scrollToBottomButton.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 15),
            scrollToBottomButton.widthAnchor.constraint(equalToConstant: 120),
            scrollToBottomButton.heightAnchor.constraint(equalToConstant: 40),
            
            clearButton.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 15),
            clearButton.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -15),
            clearButton.widthAnchor.constraint(equalToConstant: 100),
            clearButton.heightAnchor.constraint(equalToConstant: 40),
            
            autoScrollSwitch.topAnchor.constraint(equalTo: scrollToBottomButton.bottomAnchor, constant: 15),
            autoScrollSwitch.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 15),
            
            autoScrollLabel.centerYAnchor.constraint(equalTo: autoScrollSwitch.centerYAnchor),
            autoScrollLabel.leadingAnchor.constraint(equalTo: autoScrollSwitch.trailingAnchor, constant: 10),
            
            pauseButton.centerYAnchor.constraint(equalTo: autoScrollSwitch.centerYAnchor),
            pauseButton.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -15),
            pauseButton.widthAnchor.constraint(equalToConstant: 100),
            pauseButton.heightAnchor.constraint(equalToConstant: 40),
            
            monitorLabel.topAnchor.constraint(equalTo: controlPanel.bottomAnchor, constant: 5),
            monitorLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    // MARK: - Timer Methods
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: timeNumber, repeats: true) { [weak self] _ in
            self?.appendText()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Text Methods
    private func appendText() {
        updateCount += 1
        
        // 在主线程更新监控标签
        DispatchQueue.main.async {
            self.monitorLabel.text = "更新次数: \(self.updateCount) 文本长度: \(self.coreTextStr.length)"
        }
        
        // 创建不同样式的文本
        let text: String
        let color: UIColor
        let fontSize: CGFloat
        
        if updateCount % 20 == 0 {
            text = "\n[新段落👌👍🎉👍👌👍🎉👍 \(updateCount)] "
            color = .systemBlue
            fontSize = 15
        } else if updateCount % 7 == 0 {
            text = "[重要👌👍👍🎉👌👍🎉👍\(updateCount)] "
            color = .systemRed
            fontSize = 15
        } else if updateCount % 13 == 0 {
            text = "【标注👍👌👍🎉👌👍🎉👍\(updateCount)】"
            color = .systemGreen
            fontSize = 14
        } else {
            text = "文字\(updateCount) "
            color = .darkGray
            fontSize = 14
        }
        
        let newText = createAttributedString(text, color: color, fontSize: fontSize)
        coreTextStr.append(newText)
        
        // 在主线程更新YYTextView
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 修复：YYTextView 追加文本的正确方式
            if let currentAttrText = self.textView.attributedText {
                let mutableAttrText = NSMutableAttributedString(attributedString: currentAttrText)
                mutableAttrText.append(newText)
                self.textView.attributedText = mutableAttrText
            } else {
                self.textView.attributedText = newText
            }
            
            // 获取文本内容的高度（适配YYTextView）
            let textHeight = self.textView.sizeThatFits(
                CGSize(width: self.textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
            ).height
            
            // 更新YYTextView的高度约束
            self.textView.constraints.forEach { constraint in
                if constraint.firstAttribute == .height {
                    constraint.constant = textHeight
                }
            }
            
            // 更新ScrollView的contentSize
            self.scrollView.contentSize = CGSize(
                width: self.scrollView.bounds.width,
                height: textHeight + 20 // 添加一些边距
            )
            
            // 如果启用自动滚动，滚动到底部
            if self.shouldAutoScroll && !self.isScrolling {
                self.scrollToBottom(animated: false)
            }
            
            // 模拟5000字符后添加分隔符
            if self.updateCount > 0 && self.updateCount % 500 == 0 {
                let separator = self.createAttributedString(
                    "\n\n━━━━━━━━ 已更新 \(self.updateCount) 次 ━━━━━━━━\n\n",
                    color: .systemPurple,
                    fontSize: 13
                )
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.coreTextStr.append(separator)
                    self.textView.attributedText = self.coreTextStr
                    
                    // 重新计算高度
                    let newTextHeight = self.textView.sizeThatFits(
                        CGSize(width: self.textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
                    ).height
                    
                    // 更新高度约束
                    self.textView.constraints.forEach { constraint in
                        if constraint.firstAttribute == .height {
                            constraint.constant = newTextHeight
                        }
                    }
                    
                    // 更新ScrollView的contentSize
                    self.scrollView.contentSize = CGSize(
                        width: self.scrollView.bounds.width,
                        height: newTextHeight + 20
                    )
                    
                    print("已更新 \(self.updateCount) 次")
                }
            }
            
            // 监控性能，每100次更新打印一次
            if self.updateCount % 100 == 0 {
                print("更新次数: \(self.updateCount), 内存使用: \(String(format: "%.2f", self.getMemoryUsage())) MB")
            }
            self.completion?(self.coreTextStr.length)
        }
    }
    
    private func createAttributedString(_ text: String, color: UIColor = .black, fontSize: CGFloat = 14) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: color,
            .paragraphStyle: createParagraphStyle()
        ]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    private func createParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 6
        return style
    }
    
    // MARK: - Control Methods
    @objc private func scrollToBottom(animated: Bool = true) {
        let bottomOffset = CGPoint(
            x: 0,
            y: max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
        )
        scrollView.setContentOffset(bottomOffset, animated: animated)
    }
    
    @objc private func clearText() {
        updateCount = 0
        coreTextStr = NSMutableAttributedString() // 清空文本
        textView.attributedText = nil // 清空YYTextView
        monitorLabel.text = "更新次数: 0"
        
        let initialText = createAttributedString("文本已清除，重新开始:\n\n", color: .systemBlue, fontSize: 15)
        coreTextStr.append(initialText)
        textView.attributedText = coreTextStr
        
        // 更新高度
        let textHeight = textView.sizeThatFits(
            CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        ).height
        
        textView.constraints.forEach { constraint in
            if constraint.firstAttribute == .height {
                constraint.constant = textHeight
            }
        }
        
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: textHeight + 20
        )
        
        if shouldAutoScroll {
            scrollToBottom(animated: true)
        }
    }
    
    @objc private func autoScrollChanged() {
        shouldAutoScroll = autoScrollSwitch.isOn
        autoScrollLabel.text = shouldAutoScroll ? "自动滚动开启" : "自动滚动关闭"
    }
    
    @objc private func toggleTimer(_ sender: UIButton) {
        sender.isSelected.toggle()
        
        if sender.isSelected {
            stopTimer()
            sender.backgroundColor = .systemGreen
        } else {
            startTimer()
            sender.backgroundColor = .systemOrange
        }
    }
    
    // MARK: - Utility Methods
    private func getMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / 1024.0 / 1024.0
        }
        
        return 0.0
    }
    
    // MARK: - Cleanup
    deinit {
        stopTimer()
    }
}

// MARK: - UIScrollViewDelegate
extension YYTextMainView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isScrolling = false
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
    }
}
