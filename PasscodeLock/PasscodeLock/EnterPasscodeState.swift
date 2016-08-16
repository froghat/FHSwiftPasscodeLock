//
//  EnterPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

let AWS_LOGIN_INFORMATION = "AWSLoginInformationKey"

public let PasscodeLockIncorrectPasscodeNotification = "passcode.lock.incorrect.passcode.notification"

struct EnterPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction: Bool
    var isTouchIDAllowed = true
    
    private var incorrectPasscodeAttempts = 0
    private var isNotificationSent = false
    
    init(allowCancellation: Bool = false) {
        
        isCancellableAction = allowCancellation
        title = localizedStringFor(key: "PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor(key: "PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        print("Accept Passcode Lock in EnterPasscodeLock called.")
        
        var currentPasscode: [String]? = nil
        
        if lock.repository.passcode != nil {
            currentPasscode = lock.repository.passcode
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
        
        if Pool.sharedInstance.user != nil {
            print("In the right closure.")
            logInAWSUser(userPassword: passcodeString, lock: lock)
        }
        else {
        
            if passcode == currentPasscode! {
                
                print("In the wrong closure.")
                lock.delegate?.passcodeLockDidSucceed(lock: lock)
                
            }
            else {
                
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
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
    
    mutating func logInAWSUser(userPassword: String, lock: PasscodeLockType) {
        
        print("In AWS login.")
        
       // isEmailVerified(callback: {(isEmailVerified: Bool) in
        
            if true {
                Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
                    
                    if task.error?._code == 11 {
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
                    
                }.onLogInSuccess {task in
                    print("In login success")
                    
                    let userDict: NSDictionary = ["hasLoggedIn": true, "email": Pool.sharedInstance.user!.username!]
                    print(userDict)
                    UserDefaults.standard.set(userDict, forKey: AWS_LOGIN_INFORMATION)
                    
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                        
                }
            }
            else {
                print("Email isn't verified.")
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .notConfirmed, priorAction: .logIn)
            }
       // })
    }
    
    func presenterLogIn(userPassword: String, lock: PasscodeLockType) {
        
        //isEmailVerified(callback: {(isEmailVerified: Bool) in
            
            if true {
                Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
                    
                    if task.error?._code == 11 {
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
                    
                    }.onLogInSuccess {task in
                        print("In login success")
                        
                        let userDict: NSDictionary = ["hasLoggedIn": true, "email": Pool.sharedInstance.user!.username!]
                        print(userDict)
                        UserDefaults.standard.set(userDict, forKey: AWS_LOGIN_INFORMATION)
                        
                        lock.delegate?.passcodeLockDidSucceed(lock: lock)
                        
                }
            }
            else {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .notConfirmed, priorAction: .logIn)
            }
        //})
    }
    
    func isEmailVerified(callback: (Bool) -> Void) {
        var isVerified: Bool = false
    
        print("In isEmailVerified()")
        print(Pool.sharedInstance.user?.username)
        print(Pool.sharedInstance.user!.getDetails())
        print(Pool.sharedInstance.user!.getDetails().result)
        
        Pool.sharedInstance.getUserDetails().onUserDetailsFailure {task in
            
            print("Failed to retrieve user details")
            
        }.onUserDetailsSuccess {task in
            
            print("Successfully retrieved user details.")
            
            if let resultDict = task.result {
                print("userDict: \(resultDict)")
                if let userDict: NSDictionary = resultDict.dictionaryWithValues(forKeys: ["userAttributes"]) as NSDictionary {
                    if let userAttributesArray = userDict.value(forKey: "userAttributes") as? NSArray {
                        print(userAttributesArray)
                        for i in 0..<userAttributesArray.count {
                            if let userAttribute = userAttributesArray[i] as? AWSCognitoIdentityProviderAttributeType {
                                if userAttribute.name == "email_verified" {
                                    if userAttribute.value != nil {
                                        if userAttribute.value! == "true" {
                                            isVerified = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            callback(isVerified)
        }
        
        print("After isEmailVerified()")
    }
    
    private mutating func postNotification() {
        
        guard !isNotificationSent else { return }
        
        let center = NotificationCenter.default
        
        center.post(name: NSNotification.Name(rawValue: PasscodeLockIncorrectPasscodeNotification), object: nil)
        
        isNotificationSent = true
    }
    
}
