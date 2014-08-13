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

**1.0(27)**

- 保存最后一次浏览的板块，下次打开会首先打开该板块。

已知问题
--------

- 因为程序依赖的库Alamofire的[bug](https://github.com/Alamofire/Alamofire/issues/17)，暂时不能在iOS 7上运行。
- **Fixed** <del>帖子列表的解析有时会出现问题。</del>
- **Fixed** <del>部分帖子无法获取全部图片。</del>
- 照片滑动切换在竖屏时有问题，出现问题时，请使用横屏浏览。
- **Fixed** <del>iPad，iOS 8上的`UIActionSheet`的Autolayout有bug，暂时用`UIAlertController`的Alert模式作为选择类别的方法。</del>
- 网络状况不好的时候，由于网络超时时间过长，HUD有时无法自动消失，需要杀掉程序后重新打开。

计划
----

1. 解决iOS 7兼容问题
2. 用HTML DOM处理，取代正则表达式来获取内容
