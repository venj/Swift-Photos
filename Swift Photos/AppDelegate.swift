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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Set Application-Wide request timeout
        SessionManager.default.session.configuration.timeoutIntervalForRequest = requestTimeOutForWeb
        MMAppSwitcher.sharedInstance().setDataSource(self)
        updateVersionNumber()
        passcodeLockPresenter.presentPasscodeLock()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        let repository = UserDefaultsPasscodeRepository()
        if !repository.hasPasscode {
            MMAppSwitcher.sharedInstance().setNeedsUpdate()
        }

        if let clearCache = UserDefaults.standard.object(forKey: ClearCacheOnExitKey) {
            if (clearCache as AnyObject).boolValue == true {
                let app = UIApplication.shared
                var bgTask:UIBackgroundTaskIdentifier = app.beginBackgroundTask(expirationHandler: {})
                bgTask = app.beginBackgroundTask(expirationHandler: {
                    app.endBackgroundTask(bgTask)
                    bgTask = UIBackgroundTaskInvalid
                })
                SDImageCache.shared().clearDisk() {
                    app.endBackgroundTask(bgTask)
                    bgTask = UIBackgroundTaskInvalid
                }
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        passcodeLockPresenter.presentPasscodeLock()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: MMAppSwitcher

    func viewForCard() -> UIView! {
        let view = UIView()
        view.backgroundColor = UIColor.white
        return view
    }
}
