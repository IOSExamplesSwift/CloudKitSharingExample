//
//  AppDelegate.swift
//  CloudKitExample
//
//  Created by Douglas Alexander on 4/20/18.
//  Copyright © 2018 Douglas Alexander. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [[.alert, .sound, .badge]], completionHandler: { (granted, Error) in
            // Handle error
        })
        application.registerForRemoteNotifications()
        
        // obtain the launch options
        if let option: NSDictionary = launchOptions as NSDictionary? {
            let remoteNotification = option[UIApplicationLaunchOptionsKey.remoteNotification]
            
            if let notification = remoteNotification {
                // pass the notificaiton key to didReceiveRemoteNotification method
                self.application(application, didReceiveRemoteNotification: notification as! [AnyHashable : Any], fetchCompletionHandler: { (result) in })
            }
        }
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)-> Void) {
            let viewController: ViewController = self.window?.rootViewController as! ViewController
            let notification: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject])
        if (notification.notificationType == CKNotificationType.query) {
            let queryNotication = notification as? CKQueryNotification
            
            if let recordID = queryNotication?.recordID {
                viewController.fetchRecord(recordID)
            }
        }
    }
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShareMetadata) {
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
            acceptSharesOperation.perShareCompletionBlock = {
                metadata, share, error in
                if let err = error {
                    print(err.localizedDescription)
                } else {
                    let viewController: ViewController = self.window?.rootViewController as! ViewController
                    viewController.fetchShare(cloudKitShareMetadata)
                    
                }
            
        }
        CKContainer(identifier: cloudKitShareMetadata.containerIdentifier).add( acceptSharesOperation)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

