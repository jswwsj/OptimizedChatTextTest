// MainView.swift
import UIKit

class MainView: UIView {
    
    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var coreTextLabel: CoreTextLabel!
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
        setupCoreTextLabel()
        setupControlPanel()
        
        // 添加初始文本
        let initialText = createAttributedString("原生 Auto Layout 示例\n\n", color: .systemBlue)
        coreTextStr.append(initialText)
        coreTextLabel.setAttributedText(coreTextStr)
        
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
    
    private func setupCoreTextLabel() {
        coreTextLabel = CoreTextLabel()
        coreTextLabel.translatesAutoresizingMaskIntoConstraints = false
        coreTextLabel.backgroundColor = .white
        contentView.addSubview(coreTextLabel)
        
        NSLayoutConstraint.activate([
            coreTextLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            coreTextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            coreTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            coreTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
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
        
        // 使用异步追加，并在完成后更新布局
        coreTextLabel.appendAttributedText(coreTextStr) { [weak self] newSize in
            guard let self = self else { return }
            
            // 更新 ScrollView 的 contentSize
            self.updateScrollViewContentSize(newSize)
            
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
                    self.coreTextLabel.appendAttributedText(separator) { _ in
                        self.updateScrollViewContentSize(self.coreTextLabel.textContainerSize)
                        print("已更新 \(self.updateCount) 次")
                    }
                }
            }
            
            // 监控性能，每100次更新打印一次
            if self.updateCount % 100 == 0 {
                print("更新次数: \(self.updateCount), 内存使用: \(String(format: "%.2f", self.getMemoryUsage())) MB")
            }
            completion?(coreTextStr.length)
        }
    }
    
    private func updateScrollViewContentSize(_ textSize: CGSize) {
        let contentHeight = max(textSize.height + 40, scrollView.bounds.height)
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: contentHeight
        )
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
        coreTextLabel.clear()
        monitorLabel.text = "更新次数: 0"
        
        let initialText = createAttributedString("文本已清除，重新开始:\n\n", color: .systemBlue, fontSize: 15)
        coreTextLabel.appendAttributedText(initialText) { [weak self] newSize in
            self?.updateScrollViewContentSize(newSize)
            if self?.shouldAutoScroll == true {
                self?.scrollToBottom(animated: true)
            }
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
extension MainView: UIScrollViewDelegate {
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
