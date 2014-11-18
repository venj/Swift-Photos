美图赏
=====

开发中...作用，你懂的。

编译
----

**请重新签代码编译，免去繁琐的冲突解决。记得先保存你的Common.swift文件。**

你需要安装最新版的Xcode 6和Cocoa Pods。然后执行如下操作：

```
$ cp Swift\ Photos/Common.swift.skel Swift\ Photos/Common.swift
(编辑，并填入正确的网址。)
$ git submodule init
$ git submodule update
$ pod install
```

然后打开Swift Photo.xcworkspace，编译安装即可。

更新记录
-------

**2.1(50, 测试版)**

- 现在点击帖子，将自动并发下载所有图片。（数百张图片时压力有点大，以后改进）

**2.0(47)**

- 修正了在加载论坛帖子列表时在文档目录创建大量空文件夹的问题。

**2.0(44, 测试版)**

- 现在已经支持iPhone 6, 6 Plus的全新分辨率
- 现在已支持TouchID解锁（感谢`LTHPasscodeViewController`）
- 换回`MWPhotoBrowser`
- iOS 7已不再支持

**2.0(38, 测试版)**

- 使用了一个兼容iOS 7+的图片浏览器
- 使用了一个兼容iOS 7+的密码工具（尚未完成）
- iPhone 6兼容基本完成

**1.2(34)**

- 加入保存缓存文件的功能（暂时只能保存已经缓存的图片）。
- 保存完成后（可能没有完整保存），该帖子标题变成蓝色。
- 打开了iTunes文件共享。
- 重构了部分代码。

**1.1(29)**

- 修正了iOS 7下的ActionSheet标题错乱的问题。
- 修正了调整了标题栏按钮顺序后，iPad上ActionSheet箭头位置错误的问题。

**1.1(28)**

- 修正了iOS 7的兼容性问题。

**1.0(27)**

- 保存最后一次浏览的板块，下次打开会首先打开该板块。

已知问题
--------

- **已修正** <del>因为程序依赖的库Alamofire的[bug](https://github.com/Alamofire/Alamofire/issues/17)，暂时不能在iOS 7上运行。</del>
- **已修正** <del>帖子列表的解析有时会出现问题。</del>
- **已修正** <del>部分帖子无法获取全部图片。</del>
- 照片滑动切换在竖屏时有问题，出现问题时，请使用横屏浏览。
- **已修正** <del>iPad，iOS 8上的`UIActionSheet`的Autolayout有bug，暂时用`UIAlertController`的Alert模式作为选择类别的方法。</del>
- 网络状况不好的时候，由于网络超时时间过长，HUD有时无法自动消失，需要杀掉程序后重新打开。
- 偶尔会发生ViewController层叠错乱。
- 密码输入控件太老。
- 照片浏览器返回按钮标题总是显示同一个标题。

计划
----

1. **已完成** <del>解决iOS 7兼容问题</del>
2. 用HTML DOM处理，取代正则表达式来获取内容
