//
//  EnterPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//
// Test

import Foundation
import AWSCognitoIdentityProvider
import SCLAlertView

let AWS_LOGIN_INFORMATION = "AWSLoginInformationKey"

public let PasscodeLockIncorrectPasscodeNotification = "passcode.lock.incorrect.passcode.notification"

struct EnterPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction: Bool
    var isTouchIDAllowed = true
    
    private var incorrectPasscodeAttempts = 0
    private var isNotificationSent = false
    
    private var alert: SCLAlertViewResponder?
    
    init(allowCancellation: Bool = false) {
        
        isCancellableAction = allowCancellation
        title = localizedStringFor(key: "PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor(key: "PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        print("Accept Passcode Lock in EnterPasscodeLock called.")
        
        alert = presentWaitingAlert()
        
        var currentPasscode: [String]? = nil
        
        if lock.repository.passcode != nil {
            currentPasscode = lock.repository.passcode
            print("Current passcode: \(passcode)")
        }
        else {
            lock.repository.savePasscode(passcode: passcode)
            
            currentPasscode = lock.repository.passcode
        }
        
        var passcodeString: String {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        if passcode == currentPasscode! {
            
            print("In the wrong closure.")
            logInAWSUser(userPassword: passcodeString, lock: lock)
            
        }
        else {
            
            lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            
            self.finishWaitingAlert(alert: self.alert!)
        }
    }
    
    mutating func registerIncorrectPasscode(lock: PasscodeLockType) -> Bool {
        incorrectPasscodeAttempts += 1
        
        print("Incorrect passcode attempts: \(incorrectPasscodeAttempts)/\(lock.configuration.maximumInccorectPasscodeAttempts)")
        
        if incorrectPasscodeAttempts >= lock.configuration.maximumInccorectPasscodeAttempts {
            
            print("Trying to tell the user the passcode is incorrect.")
            
            postNotification()
            
            return true
        }
        
        return false
    }
    
    func logInAWSUser(userPassword: String, lock: PasscodeLockType) {
        
        print("In AWS login.")
        
       // isEmailVerified(callback: {(isEmailVerified: Bool) in
        
            if true {
                Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
                    
                    if task.error?._code == 11 || task.error?._code == 16 {
                        print("That is the wrong passcode. Literally go fuck yourself.")
                        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .incorrectPasscode, priorAction: .unknown)
                    }
                    else if task.error?._code == 12 {
                        print("This user is not signed up.")
                        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .invalidEmail, priorAction: .unknown)
                    }
                    else {
                        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
                    }
                    
                    self.finishWaitingAlert(alert: self.alert!)
                    
                }.onLogInSuccess {task in
                    print("In login success")
                    
                    let userDict: NSDictionary = ["hasLoggedIn": true, "email": Pool.sharedInstance.user!.username!]
                    print(userDict)
                    UserDefaults.standard.set(userDict, forKey: AWS_LOGIN_INFORMATION)
                    
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                    
                    self.finishWaitingAlert(alert: self.alert!)
                        
                }
            }
            else {
                print("Email isn't verified.")
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .notConfirmed, priorAction: .logIn)
            }
       // })
    }
    
    func presenterLogIn(userPassword: String, lock: PasscodeLockType) {
        Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
            
            if task.error?._code == 11 || task.error?._code == 16 {
                print("That is the wrong passcode. Literally go fuck yourself.")
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .incorrectPasscode, priorAction: .unknown)
            }
            else if task.error?._code == 12 {
                print("This user is not signed up.")
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .invalidEmail, priorAction: .unknown)
            }
            else {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
            
            self.finishWaitingAlert(alert: self.alert!)
            
            }.onLogInSuccess {task in
                print("In login success")
                
                let userDict: NSDictionary = ["hasLoggedIn": true, "email": Pool.sharedInstance.user!.username!]
                print(userDict)
                UserDefaults.standard.set(userDict, forKey: AWS_LOGIN_INFORMATION)
                
                lock.delegate?.passcodeLockDidSucceed(lock: lock)
                
                self.finishWaitingAlert(alert: self.alert!)
        }
    }
    
    private mutating func postNotification() {
        
        guard !isNotificationSent else { return }
        
        let center = NotificationCenter.default
        
        center.post(name: NSNotification.Name(rawValue: PasscodeLockIncorrectPasscodeNotification), object: nil)
        
        isNotificationSent = true
    }
    
    //MARK: - SCL Alert View Methods
    
    public func presentWaitingAlert() -> SCLAlertViewResponder {
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        
        let responder: SCLAlertViewResponder = SCLAlertView(appearance: appearance).showWait("Waiting for response", subTitle: "Please wait for a login response from the server.")
        
        return responder
    }
    
    public func finishWaitingAlert(alert: SCLAlertViewResponder) {
        alert.close()
    }
    
}
