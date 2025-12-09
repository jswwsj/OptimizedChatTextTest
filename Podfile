# 国内网络必加镜像源，避免Git克隆失败
source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '15.0'
target 'OptimizedChatTextTest' do
  use_frameworks! :linkage => :static

  # 关键：直接从Git仓库拉取，指定Tag（1.0.8是YYKit最后稳定版，推荐用这个）
  pod 'YYKit', :git => 'https://github.com/ibireme/YYKit.git', :tag => '1.0.7'
end