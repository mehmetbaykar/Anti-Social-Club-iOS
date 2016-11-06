//
//  ShareKeysViewController.swift
//  Anti-Social Club
//
//  Created by Arthur De Araujo on 10/18/16.
//  Copyright © 2016 UB Anti-Social Club. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import Crashlytics
import StoreKit
import Spring

class ShareKeysViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    var keyArray : [AccessKey] = []
    var recipientTextField: UITextField!
    var productArray : [SKProduct] = []
    
    @IBOutlet weak var keysTableView: UITableView!
    @IBOutlet weak var buyMoreKeysButton: SpringButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keysTableView.delegate = self
        keysTableView.dataSource = self
        
        let defaults = UserDefaults.standard
        attemptRetrieveUserKeys(token: defaults.string(forKey: "token")!)
        
        buyMoreKeysButton.isHidden = true
        
        // Do any additional setup after loading the view.
        Answers.logContentView(
            withName: "Key View",
            contentType: "View",
            contentId: "Key",
            customAttributes: [:])
        
        SKPaymentQueue.default().add(self)
        requestProducts()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if !(self.navigationController?.toolbar.isHidden)! {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if  (self.navigationController?.toolbar.isHidden)! {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
        SKPaymentQueue.default().remove(self)
    }
    
    func attemptRetrieveUserKeys(token : String)
    {
        print("Attempting to retrieve keys from token: \(token)")
        
        let parameters = ["token" : token]
        
        let activityView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityView.center=self.view.center;
        activityView.frame = self.view.frame
        activityView.startAnimating()
        self.view.addSubview(activityView)
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_RETRIEVE_USER_KEYS, method: .post, parameters: parameters)
            .responseJSON()
                {
                    response in
                    
                    activityView.stopAnimating()
                    activityView.removeFromSuperview()
                    
                    self.keyArray.removeAll()
                    
                    switch response.result
                    {
                    case .success(let responseData):
                        let json = JSON(responseData)
                        
                        // Handle any errors
                        if json["error"].bool == true
                        {
                            print("ERROR: \(json["error_message"].stringValue)")
                            let alert = UIAlertController(title: "Error", message: "Network Error! Please try again later", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            
                            return
                        }
                        
                        let jsonArray = json["keys"].array
                        for subJSON in jsonArray!
                        {
                            if let key : AccessKey = AccessKey(json: subJSON)
                            {
                                self.keyArray+=[key]
                            }
                            
                        }
                        self.keysTableView.reloadData()
                        
                    case .failure(let error):
                        print("Request failed with error: \(error)")
                        (self.navigationController as! CustomNavigationController).networkError()
                        
                        return
                    }
        }
    }
    
    func attemptSendKey(token : String, key : String, recipientEmail : String)
    {
        print("Attempting to send key\n\tKey: \(key)\n\tTo: \(recipientEmail)")
        
        let parameters = ["token" : token, "key" : key, "recipient_email" : recipientEmail]
        
        let activityView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityView.center=self.view.center;
        activityView.frame = self.view.frame
        activityView.startAnimating()
        self.view.addSubview(activityView)
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_SEND_INVITE, method: .post, parameters: parameters)
            .responseJSON()
                {
                    response in
                    
                    activityView.stopAnimating()
                    activityView.removeFromSuperview()
                    
                    switch response.result
                    {
                    case .success(let responseData):
                        let json = JSON(responseData)
                        //Don't do anything if it succesfully went through
                        let alert = UIAlertController(title: "Success!", message: "You're key was sent to \(recipientEmail)", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        
                        Answers.logInvite(withMethod: "Email Key", customAttributes: [:])
                        
                    case .failure(let error):
                        print("Request failed with error: \(error)")
                        (self.navigationController as! CustomNavigationController).networkError()
                        
                        return
                    }
        }
    }
    
    func animatePurchaseButton(hidden: Bool){
        if hidden == false{
            buyMoreKeysButton.isHidden = false
            self.buyMoreKeysButton.animate()
        }else{
            self.buyMoreKeysButton.animate()
            buyMoreKeysButton.alpha = 1.0
            UIView.animate(withDuration: 0.3, animations: {
                self.buyMoreKeysButton.alpha = 0.0
            }, completion: { error in
                self.buyMoreKeysButton.isHidden = true
            })
        }
    }
    
    func requestProducts() {
        let productIds : Set<String> = [Constants.Products.PRODUCT_ACCESS_KEY];
        let productsRequest : SKProductsRequest = SKProductsRequest(productIdentifiers: productIds);
        productsRequest.delegate = self;
        productsRequest.start();
    }
    
    func purchaseProduct(_ product: SKProduct) {
        print ("Initiating purchase of \(product.productIdentifier)")
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func onPurchaseSuccess(productId: String, transaction : SKPaymentTransaction) {
        LOG("Purchase Success \(productId)")
        
        if let receiptURL = Bundle.main.appStoreReceiptURL,
            let receipt = NSData(contentsOf: receiptURL) {
            attemptConfirmPurchase(productId: productId, receipt: receipt, transaction: transaction)
        }
    }
    
    func onPurchaseFailed(productId: String) {
        LOG("Purchase Failed! \(productId)")
    }
    
    func getProduct(productId: String) -> SKProduct? {
        for p in productArray {
            if p.productIdentifier == productId {
                return p
            }
        }
        
        return nil
    }
    
    func isPurchasingAllowed() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    func attemptConfirmPurchase(productId: String, receipt: NSData, transaction : SKPaymentTransaction)
    {
        print("Attempting to confirm purchase for \(productId)")
        
        let parameters = ["token" : UserDefaults.standard.string(forKey: "token")!, "product_id" : productId, "app_receipt" : receipt.base64EncodedString()]
        
        Alamofire.request(Constants.API.ADDRESS + Constants.API.CALL_CONFIRM_PURCHASE, method: .post, parameters: parameters)
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
                        
                        self.onConfirmPurchaseSuccess(transaction: transaction)
                        return
                        
                    case .failure(let error):
                        print("Request failed with error: \(error)")
                        
                        self.onConfirmPurchaseFailed()
                        return
                    }
        }
    }
    
    func onConfirmPurchaseSuccess(transaction : SKPaymentTransaction)
    {
        print("ConfirmPurchase succeded.")
        
        attemptRetrieveUserKeys(token: UserDefaults.standard.string(forKey: "token")!)
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    func onConfirmPurchaseFailed()
    {
        print("ConfirmPurchase failed!")
    }
    
    // MARK: - Actions
    
    @IBAction func pressedPurchaseMoreKeys(_ sender: AnyObject) {
        print("Pressed On Purchase More Keys")
        
        animatePurchaseButton(hidden: true)
        
        if !isPurchasingAllowed() {
            // TODO show a dialog saying that purchasing is not available
            let alert = UIAlertController(title: "Sorry!", message: "Purchasing is currently not avaliable for your device", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
            return
        }
        
        if let accessKeyProduct = getProduct(productId: Constants.Products.PRODUCT_ACCESS_KEY) {
            purchaseProduct(accessKeyProduct)
        }
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        LOG("productsRequest didReceiveResponse")
        
        let products = response.products
        for p in products {
            LOG("Got product: \(p.productIdentifier) \(p.localizedTitle) \(p.localizedDescription) \(p.price.floatValue)")
            
            productArray += [p]
        }
        animatePurchaseButton(hidden: false)
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        LOG("Failed to load list of products!")
        LOG("Error: \(error.localizedDescription)")
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                complete(transaction: transaction)
                animatePurchaseButton(hidden: false)
                break
            case .failed:
                fail(transaction: transaction)
                animatePurchaseButton(hidden: false)
                break
            case .restored:
                restore(transaction: transaction)
                animatePurchaseButton(hidden: false)
                break
            case .deferred:
                break
            case .purchasing:
                break
            }
        }
    }
    
    private func complete(transaction: SKPaymentTransaction) {
        print("complete...")
        
        onPurchaseSuccess(productId: transaction.payment.productIdentifier, transaction: transaction)
    }
    
    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        
        print("restore... \(productIdentifier)")
        
        onPurchaseSuccess(productId: productIdentifier, transaction: transaction)
    }
    
    private func fail(transaction: SKPaymentTransaction) {
        print("fail...")
        
        if let transactionError = transaction.error as? NSError {
            if transactionError.code != SKError.paymentCancelled.rawValue {
                print("Transaction Error: \(transaction.error?.localizedDescription)")
            }
        }
        
        onPurchaseFailed(productId: transaction.payment.productIdentifier)
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return keyArray.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 8
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keyCell", for: indexPath) as! ShareKeyTableViewCell
        
        cell.configureCellWithKey(key: keyArray[indexPath.section])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! ShareKeyTableViewCell
        
        if !cell.isRedeemed! {
            let alert = UIAlertController(title: "Share Key", message: "Please enter your friend's email address.", preferredStyle: .alert)
            
            alert.addTextField(configurationHandler: configurationTextField)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:handleCancel))
            alert.addAction(UIAlertAction(title: "Share", style: .default, handler:{ (UIAlertAction) in
                print("User shared key: \(cell.accessKey!) to \(self.recipientTextField.text!)")
                let defaults = UserDefaults.standard
                self.attemptSendKey(token: defaults.string(forKey: "token")!, key: cell.accessKey!, recipientEmail: self.recipientTextField.text!)
            }))
            self.present(alert, animated: true, completion: {
                print("completion block")
            })
            cell.setSelected(false, animated: true)
        }
    }
    
    func configurationTextField(textField: UITextField!)
    {
        print("Generating TextField")
        textField.placeholder = "friend@buffalo.edu"
        recipientTextField = textField
    }
    
    func handleCancel(alertView: UIAlertAction!)
    {
        print("Cancelled")
    }
    
    /* -(void)handleKeyboardWillShow:(NSNotification *)sender{
     CGSize keyboardSize = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
     
     self.bottomBar.transform = CGAffineTransformMakeTranslation(0, -keyboardSize.height);
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
