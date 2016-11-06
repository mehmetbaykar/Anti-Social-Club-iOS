//
//  AppDelegate.swift
//  Anti-Social Club
//
//  Created by Declan Hopkins on 10/10/16.
//  Copyright © 2016 Cult of the Old Gods. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import Firebase
import UserNotifications
import SwiftyJSON

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, FIRMessagingDelegate {

    var window: UIWindow?
    var notificationData: [AnyHashable : Any]?
    var inAppNotification : Bool?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        LOG("application didFinishLaunchingWithOptions")

        // Initialize Fabric
        Fabric.with([Crashlytics.self])
        
        // Initialize Firebase (For FCM Push Notifications)
        LOG("Initializing FCM...")
        
        FIRApp.configure()
        FIRAnalyticsConfiguration.sharedInstance().setAnalyticsCollectionEnabled(false)
        registerForFCM(application: application);
        
        LOG("Initialized FCM!")
        
        inAppNotification = false
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        FIRMessaging.messaging().disconnect()
        LOG("Disconnected from FCM.")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if notificationData != nil {
            sendNotificationData(userInfo: notificationData!)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LOG("Device failed to register for remote notifications! \(error)")
    }

    func registerForFCM(application : UIApplication) {
        if #available(iOS 10.0, *) {
          let authOptions : UNAuthorizationOptions = [.alert, .badge, .sound]
          UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: {_,_ in })

          // For iOS 10 display notification (sent via APNS)
          UNUserNotificationCenter.current().delegate = self
          
          // For iOS 10 data message (sent via FCM)
          FIRMessaging.messaging().remoteMessageDelegate = self

        } else {
          let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
          application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()

        if let token = FIRInstanceID.instanceID().token()
        {
            LOG("Got FCM token \(token)")
        }
        else
        {
            LOG("No FCM token found!")
        }
        
        //connectToFCM()
    }
    
    func tokenRefreshNotification(_ notification: Notification) {
        if let refreshedToken = FIRInstanceID.instanceID().token() {
            LOG("Got new FCM InstanceID token: \(refreshedToken)")
        }

        // Connect to FCM since connection may have failed when attempted before having a token.
        //connectToFCM()
    }
    
    func connectToFCM() {
        LOG("Connecting to FCM..");
    
        FIRMessaging.messaging().connect {
            (error) in
            
            if (error != nil) {
                LOG("Failed to connect to FCM! \(error)")
            } else {
                LOG("Connected to FCM.")
                if let token = FIRInstanceID.instanceID().token()
                {
                    LOG("Got FCM token \(token)")
                }
            }
        }
    }
    
    // iOS 7+
    // Called when the app receives a data message
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        LOG("application didReceiveRemoteNotification")
        let dataJSON = JSON(userInfo)
        
        print(dataJSON)
        
        inAppNotification = false
        notificationData = userInfo
        
        print("test")
    }
    
    // iOS 10+
    // Called when the app receives a data message
    func applicationReceivedRemoteMessage(_ remoteMessage: FIRMessagingRemoteMessage) {
        LOG("applicationReceivedRemoteMessage")
    }
    
    func sendNotificationData(userInfo: [AnyHashable : Any]){
        if (userInfo["aps"] == nil)
        {
            return;
        }
        
        let apsJSON = JSON(userInfo["aps"]!)
        if let messageBody = apsJSON["alert"].string {
            // Display a local notification if the user is inside the app when the push notification arrives
            let notificationJSON = JSON(userInfo)
            let notificationJSONDictionary = notificationJSON.dictionary!
            
            print("got \(notificationJSONDictionary["notification_type"]!)")
            
            let notificationType = notificationJSON["notification_type"].string // comment or badge
            let postId : Int = Int(notificationJSON["post_id"].string!)!
            
            let notificationInfoDict : NSDictionary = ["body" : messageBody, "post_id" : postId, "notification_type" : notificationType!]
            
            if inAppNotification!{
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "localNotification"), object: nil, userInfo: notificationInfoDict as? [AnyHashable : Any])
            }else{
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "remoteNotification"), object: nil, userInfo: notificationInfoDict as? [AnyHashable : Any])
            }
        }
    }
    
}

@available(iOS 10, *)
extension AppDelegate {

    // iOS 10+
    // Called when a notification message is delivered to the foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        LOG("Got foreground notification!")
        inAppNotification = true
        sendNotificationData(userInfo: self.notificationData!)
    }
}


