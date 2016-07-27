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
    
    private var inccorectPasscodeAttempts = 0
    private var isNotificationSent = false
    
    init(allowCancellation: Bool = false) {
        
        isCancellableAction = allowCancellation
        title = localizedStringFor(key: "PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor(key: "PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        guard let currentPasscode = lock.repository.passcode else {
            return
        }
        
        var passcodeString: String {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        if Pool.sharedInstance.user != nil {
            logInAWSUser(userPassword: passcodeString, lock: lock)
        }
        else {
        
            if passcode == currentPasscode {
                
                lock.delegate?.passcodeLockDidSucceed(lock: lock)
                
            }
            else {
                
                inccorectPasscodeAttempts += 1
                
                if inccorectPasscodeAttempts >= lock.configuration.maximumInccorectPasscodeAttempts {
                    
                    postNotification()
                }
                
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
        }
    }
    
    func logInAWSUser(userPassword: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
            
            if task.error?.code == 11 {
                print("That is the wrong passcode. Literally go fuck yourself.")
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .incorrectPasscode, priorAction: .unknown)
            }
            else {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
            
        }.onLogInSuccess {task in
            
            let userDict: NSDictionary = ["hasLoggedIn": true, "email": Pool.sharedInstance.user!.username!, "password": userPassword]
            print(userDict)
            UserDefaults.standard.set(userDict, forKey: AWS_LOGIN_INFORMATION)
            
            lock.delegate?.passcodeLockDidSucceed(lock: lock)
                
        }
    }
    
    private mutating func postNotification() {
        
        guard !isNotificationSent else { return }
            
        let center = NotificationCenter.default
        
        center.post(name: NSNotification.Name(rawValue: PasscodeLockIncorrectPasscodeNotification), object: nil)
        
        isNotificationSent = true
    }
    
}
