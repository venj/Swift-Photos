美图赏
=====

开发中...作用，你懂的。

编译
----

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
