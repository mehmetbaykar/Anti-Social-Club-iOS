//
//  SettingsViewController.swift
//  Anti-Social Club
//
//  Created by Arthur De Araujo on 10/15/16.
//  Copyright © 2016 UB Anti-Social Club. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import Crashlytics

class SettingsViewController: UIViewController {

    @IBOutlet weak var funnyBadgeLabel: UILabel!
    @IBOutlet weak var notamusedBadgeLabel: UILabel!
    @IBOutlet weak var heartBadgeLabel: UILabel!
    @IBOutlet weak var likeBadgeLabel: UILabel!
    @IBOutlet weak var dislikeBadgeLabel: UILabel!
    
    @IBOutlet weak var rankLabel: UILabel!
    @IBOutlet weak var dateJoinedLabel: UILabel!
    
    var segueingToDeactivate : Bool = false
    var userToken : String?
    
    // MARK - SettingsViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveUserInfo()
        
        userToken = (self.navigationController as! CustomNavigationController).userToken
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !(self.navigationController?.toolbar.isHidden)! {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if  !segueingToDeactivate && (self.navigationController?.toolbar.isHidden)! {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func retrieveUserInfo()
    {
        let token = UserDefaults.standard.string(forKey: "token")!
        let parameters = ["token" : token]
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_RETRIEVE_USER_INFO, method: .post, parameters: parameters)
            .responseJSON()
                {
                    response in
                    
                    switch response.result
                    {
                    case .success(let responseData):
                        let json = JSON(responseData)
                        
                        // Handle any errors
                        if json["error"].bool == true
                        {
                            print("ERROR: \(json["error_message"].stringValue)")
                            return
                        }
                        
                        // Parse returned user info
                        if (json["user_info"].dictionary != nil)
                        {
                            let userInfoJSON = json["user_info"].dictionary!
                            
                            let rankId : Int = userInfoJSON["rank"]!.intValue
                            let creationTimeStamp   : String = userInfoJSON["creation_timestamp"]!.stringValue
                            let badgeFunnyCount     : Int = userInfoJSON["badge_funny_count"]!.intValue
                            let badgeDumbCount      : Int = userInfoJSON["badge_dumb_count"]!.intValue
                            let badgeLoveCount      : Int = userInfoJSON["badge_love_count"]!.intValue
                            let badgeAgreeCount     : Int = userInfoJSON["badge_agree_count"]!.intValue
                            let badgeDisagreeCount  : Int = userInfoJSON["badge_disagree_count"]!.intValue
                            
                            self.funnyBadgeLabel.text = String(badgeFunnyCount)
                            self.notamusedBadgeLabel.text = String(badgeDumbCount)
                            self.heartBadgeLabel.text = String(badgeLoveCount)
                            self.likeBadgeLabel.text = String(badgeAgreeCount)
                            self.dislikeBadgeLabel.text = String(badgeDisagreeCount)
                            
                            if rankId == 0 {
                                self.rankLabel.text = "Member"
                            }else if rankId == 1 {
                                self.rankLabel.text = "Pioneer"
                            }else if rankId == 2 {
                                self.rankLabel.text = "Moderator"
                            }else if rankId == 3 {
                                self.rankLabel.text = "Administrator"
                            }
                            
                            let tempDateFormatter = DateFormatter()
                            tempDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            tempDateFormatter.timeZone = TimeZone(identifier: "GMT")
                            tempDateFormatter.locale = Locale(identifier: "en_US")
                            
                            let creationDate = tempDateFormatter.date(from: creationTimeStamp)
                            
                            let shortDateFormatter = DateFormatter()
                            shortDateFormatter.dateStyle = DateFormatter.Style.short
                            tempDateFormatter.timeZone = TimeZone(identifier: "GMT")
                            shortDateFormatter.locale = Locale(identifier: "en_US")
                            self.dateJoinedLabel.text = shortDateFormatter.string(from: creationDate!)
                            
                            print("Got user info! Rank id is \(rankId)")
                            
                            return
                        }
                        
                        print("Test")
                        
                    case .failure(let error):
                        print("Request failed with error: \(error)")
                        return
                    }
        }
    }
    
    // MARK - Actions

    @IBAction func pressedOnDeactivateDevice(_ sender: AnyObject) {
        let deactivateAlert = UIAlertController(title: "Deactivate Device", message: "Are you sure you want to deactivate your device? To activate another device you’ll need to confirm your email again", preferredStyle: UIAlertControllerStyle.alert)
        
        deactivateAlert.addAction(UIAlertAction(title: "Deactivate", style: .destructive, handler: { (action: UIAlertAction!) in
            print("User Deactivated Account")
            self.segueingToDeactivate = true
            Answers.logCustomEvent(withName: "Deactivate", customAttributes: [:])
            self.attemptToDeactivate()
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "token")
            self.navigationController?.popViewController(animated: false)
            self.performSegue(withIdentifier: "confirmNameDeactivateSegue", sender: nil)
        }))
        
        deactivateAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
            print("Handle Cancel Logic here")
        }))
        
        present(deactivateAlert, animated: true, completion: nil)
    }
    
    func attemptToDeactivate()
    {
        print("Attempting to deactivate user with token: \(userToken!)")
        
        let parameters = ["token" : userToken!]
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_DEACTIVATE_USER, method: .post, parameters: parameters)
            .responseJSON()
                {
                    response in
                    
                    switch response.result
                    {
                    case .success(let responseData):
                        let json = JSON(responseData)
                        
                        // Handle any errors
                        if json["error"].bool == true
                        {
                            print("ERROR: \(json["error_message"].stringValue)")
                            
                            return
                        }
                        
                    case .failure(let error):
                        print("Request failed with error: \(error)")
                        
                        return
                    }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        /*if (segue.identifier == "shareKeySegue")
        {
            let destination = segue.destination as! ShareKeysViewController
            segueingToShareKeyVC = true
        }*/
    }
    

}
