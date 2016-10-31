//
//  ConfirmEmailViewController.swift
//  Anti-Social Club
//
//  Created by Declan Hopkins on 10/15/16.
//  Copyright © 2016 UB Anti-Social Club. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class ConfirmEmailViewController: UIViewController, UITextFieldDelegate
{
    var userName : String?
    var errorText : String?

    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var errorTextView: UITextView!
    @IBOutlet weak var emailVerifiCodeTextField: UITextField!
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        emailVerifiCodeTextField.delegate = self
        
        if userName == nil
        {
            print("userName was nil in the ConfirmEmailViewController, Did you make sure to pass it from another view controller?")
            
            return
        }
        
        if (errorText != nil) {
            errorTextView.text = errorText
        }
        
        // This step is when the user inputs the confirmation key that was sent to their email address.
        //let key = "F921" // TODO: Get this from user input
        //attemptConfirmEmail(name: userName!, key: key)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }

    func attemptConfirmEmail(name : String, key : String)
    {
        print("Attempting to confirm key \(key) for user named \(name)")
        
        let parameters = ["name" : name, "key" : key]

        let activityView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityView.center=submitButton.center;
        activityView.frame = submitButton.frame
        activityView.startAnimating()
        submitButton.superview?.addSubview(activityView)
        submitButton.isHidden = true
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_CONFIRM_EMAIL, method: .post, parameters: parameters)
        .responseJSON()
        {
            response in
            
            activityView.stopAnimating()
            activityView.removeFromSuperview()
            self.submitButton.isHidden = false
            
            switch response.result
            {
                case .success(let responseData):
                    let json = JSON(responseData)

                    // Handle any errors
                    if json["error"].bool == true
                    {
                        print("ERROR: \(json["error_message"].stringValue)")
                        self.onConfirmFailure()

                        return
                    }
                
                    // Key not valid
                    if json["success"].bool == false
                    {
                        self.onKeyNotValid()
                        
                        return
                    }
                
                    // Retrieve the token
                    if let token = json["token"].string
                    {
                        // Okay, we've retrieved the token from the server.
                        // This means we are all registered. We need to save this token!
                        
                        let defaults = UserDefaults.standard
                        defaults.set(token, forKey: "token")
                    }
                
                    self.onConfirmSuccess()

                case .failure(let error):
                    print("Request failed with error: \(error)")
                    self.onConfirmFailure()
                    
                    return
            }
        }
    }
    
    func onConfirmSuccess()
    {
        print("Key was good! User is now confirmed and ready to use the app! Log them in!")
        performSegue(withIdentifier: "loginSegue", sender: nil)
    }
    
    func onConfirmFailure()
    {
        print("Failed to confirm key!")
        errorTextView.text = "Network Error!\nPlease try again later!"
        // TODO:
        // Display some sort of error message here. This method is called when there is a serverside error
        // or if it can't connect. On the Android version, it just makes a "NETWORK ERROR" show up in red text,
        // with a retry button.
    }
    
    func onKeyNotValid()
    {
        print("The key was not correct, check your email again you dingus")
        errorTextView.text = "Incorrect Key!\nCheck your email again you dingus"
        // TODO:
        // Display some sort of error message here.
    }
    
    // MARK: - TextField
    
    //Set Character limit
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        
        let newLength = text.characters.count + string.characters.count - range.length
        return newLength <= 4 // Bool
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    // MARK: - Actions
    
    @IBAction func submitEmailCode(_ sender: AnyObject) {
        attemptConfirmEmail(name: userName!, key: emailVerifiCodeTextField.text!)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if (segue.identifier == "loginSegue")
        {
            let destination = segue.destination as! LoginViewController
            destination.userName = userName
        }
    }

}
