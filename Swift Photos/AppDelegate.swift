//
//  AppDelegate.swift
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

import UIKit
import Alamofire
import MMAppSwitcher
import SDWebImage
import PasscodeLock

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, MMAppSwitcherDataSource {
                            
    var window: UIWindow?

    lazy var passcodeLockPresenter: PasscodeLockPresenter = {
        let configuration = PasscodeLockConfiguration()
        let presenter = PasscodeLockPresenter(mainWindow: self.window, configuration: configuration)
        return presenter
    }()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        // Set Application-Wide request timeout
        Manager.sharedInstance.session.configuration.timeoutIntervalForRequest = requestTimeOutForWeb
        MMAppSwitcher.sharedInstance().setDataSource(self)
        updateVersionNumber()
        passcodeLockPresenter.presentPasscodeLock()
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        MMAppSwitcher.sharedInstance().setNeedsUpdate()
        
        if NSUserDefaults.standardUserDefaults().objectForKey(ClearCacheOnExitKey)?.boolValue == true {
            let app = UIApplication.sharedApplication()
            var bgTask:UIBackgroundTaskIdentifier = app.beginBackgroundTaskWithExpirationHandler() {}
            bgTask = app.beginBackgroundTaskWithExpirationHandler() {
                app.endBackgroundTask(bgTask)
                bgTask = UIBackgroundTaskInvalid
            }
            SDImageCache.sharedImageCache().clearDiskOnCompletion() {
                app.endBackgroundTask(bgTask)
                bgTask = UIBackgroundTaskInvalid
            }
        }
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        passcodeLockPresenter.presentPasscodeLock()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: MMAppSwitcher

    func appSwitcher(appSwitcher: MMAppSwitcher!, viewForCardWithSize size: CGSize) -> UIView! {
        let frame = CGRectMake(0.0, 0.0, size.width, size.height)
        let view = UIView(frame: frame)
        view.backgroundColor = UIColor.whiteColor()
        return view
    }

    func viewForCard() -> UIView! {
        let view = UIView()
        view.backgroundColor = UIColor.whiteColor()
        return view
    }
}
