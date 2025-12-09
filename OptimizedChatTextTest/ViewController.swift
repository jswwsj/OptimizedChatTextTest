// ViewController.swift
import UIKit
public let timeNumber = 0.08
class ViewController: UIViewController {
    
    private var mainView: MainView!
    private var fpsLabel: FPSLabel!
    private var targetCount = 1000
    private var countNumber = 1000
    private var fpsNumber = 0.0
    private var fpsCount = 0
    private lazy var labelMainView: LabelMainView = {
        let view = LabelMainView()
        return view
    }()
    //TextMainView
    private lazy var textMainView: TextMainView = {
        let view = TextMainView()
        return view
    }()
    
    private lazy var yyLabelMainView: YYLabelMainView = {
        let view = YYLabelMainView()
        return view
    }()
    
    //YYTextMainView
    private lazy var yyTextMainView: YYTextMainView = {
        let view = YYTextMainView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let type = 1
        if type == 1 {
            setupMainView()
        }else if type == 2 {
            setupLabelMainView()
        }else if type == 3 {
            setupTextMainView()
        }else if type == 4 {
            setupYYLabelMainView()
        }else if type == 5 {
            setupYYTextMainView()
        }
        
        setupFPSLabel()
        
    }
    private func setupFPSLabel() {
        fpsLabel = FPSLabel(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
        fpsLabel.sizeToFit()
        self.view.addSubview(fpsLabel)
    }
    
    private func setupMainView() {
        // 创建 MainView 并添加到视图控制器
        mainView = MainView()
        mainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainView)
        
        // 设置约束，让 MainView 填满整个视图
        NSLayoutConstraint.activate([
            mainView.topAnchor.constraint(equalTo: view.topAnchor),
            mainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -20)
        ])
        
        mainView.completion = {[weak self] length  in
            guard let self = self else {return}
            if (length < targetCount) {
                fpsCount += 1
                fpsNumber += fpsLabel.fpsCount
            }else {
                print("监控 \(length - self.countNumber)到\(length) fps平均值 = \(self.fpsNumber/Double(fpsCount))")
                fpsCount = 0
                fpsNumber = 0
                targetCount += countNumber
            }
        }
    }
    
    private func setupLabelMainView() {
        // 创建 MainView 并添加到视图控制器
        labelMainView = LabelMainView()
        labelMainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelMainView)
        
        // 设置约束，让 MainView 填满整个视图
        NSLayoutConstraint.activate([
            labelMainView.topAnchor.constraint(equalTo: view.topAnchor),
            labelMainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            labelMainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            labelMainView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -20)
        ])
        
        labelMainView.completion = {[weak self] length  in
            guard let self = self else {return}
            if (length < targetCount) {
                fpsCount += 1
                fpsNumber += fpsLabel.fpsCount
            }else {
                print("监控 \(length - self.countNumber)到\(length) fps平均值 = \(self.fpsNumber/Double(fpsCount))")
                fpsCount = 0
                fpsNumber = 0
                targetCount += countNumber
            }
        }
    }
    
    private func setupTextMainView() {
        // 创建 MainView 并添加到视图控制器
        textMainView = TextMainView()
        textMainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textMainView)
        
        // 设置约束，让 MainView 填满整个视图
        NSLayoutConstraint.activate([
            textMainView.topAnchor.constraint(equalTo: view.topAnchor),
            textMainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textMainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textMainView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -20)
        ])
        
        textMainView.completion = {[weak self] length  in
            guard let self = self else {return}
            if (length < targetCount) {
                fpsCount += 1
                fpsNumber += fpsLabel.fpsCount
            }else {
                print("监控 \(length - self.countNumber)到\(length) fps平均值 = \(self.fpsNumber/Double(fpsCount))")
                fpsCount = 0
                fpsNumber = 0
                targetCount += countNumber
            }
        }
    }
    
    //YYLabelMainView
    private func setupYYLabelMainView() {
        // 创建 MainView 并添加到视图控制器
        yyLabelMainView = YYLabelMainView()
        yyLabelMainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(yyLabelMainView)
        
        // 设置约束，让 MainView 填满整个视图
        NSLayoutConstraint.activate([
            yyLabelMainView.topAnchor.constraint(equalTo: view.topAnchor),
            yyLabelMainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            yyLabelMainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            yyLabelMainView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -20)
        ])
        
        yyLabelMainView.completion = {[weak self] length  in
            guard let self = self else {return}
            if (length < targetCount) {
                fpsCount += 1
                fpsNumber += fpsLabel.fpsCount
            }else {
                print("监控 \(length - self.countNumber)到\(length) fps平均值 = \(self.fpsNumber/Double(fpsCount))")
                fpsCount = 0
                fpsNumber = 0
                targetCount += countNumber
            }
        }
    }
    
    private func setupYYTextMainView() {
        // 创建 MainView 并添加到视图控制器
        yyTextMainView = YYTextMainView()
        yyTextMainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(yyTextMainView)
        
        // 设置约束，让 MainView 填满整个视图
        NSLayoutConstraint.activate([
            yyTextMainView.topAnchor.constraint(equalTo: view.topAnchor),
            yyTextMainView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            yyTextMainView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            yyTextMainView.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -20)
        ])
        
        yyTextMainView.completion = {[weak self] length  in
            guard let self = self else {return}
            if (length < targetCount) {
                fpsCount += 1
                fpsNumber += fpsLabel.fpsCount
            }else {
                print("监控 \(length - self.countNumber)到\(length) fps平均值 = \(self.fpsNumber/Double(fpsCount))")
                fpsCount = 0
                fpsNumber = 0
                targetCount += countNumber
            }
        }
    }
}
