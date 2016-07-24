//
//  EnterPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

public let PasscodeLockIncorrectPasscodeNotification = "passcode.lock.incorrect.passcode.notification"

struct EnterPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction: Bool
    var isTouchIDAllowed = true
    
    private var emailToLogIn: String?
    private var inccorectPasscodeAttempts = 0
    private var isNotificationSent = false
    
    init(userEmail: String?, allowCancellation: Bool = false) {
        
        emailToLogIn = userEmail
        isCancellableAction = allowCancellation
        title = localizedStringFor(key: "PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor(key: "PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    init(allowCancellation: Bool = false) {
        
        isCancellableAction = allowCancellation
        title = localizedStringFor(key: "PasscodeLockEnterTitle", comment: "Enter passcode title")
        description = localizedStringFor(key: "PasscodeLockEnterDescription", comment: "Enter passcode description")
    }
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        guard let currentPasscode = lock.repository.passcode else {
            return
        }
        
        if emailToLogIn != nil {
            logInAWSUser(userPassword: lock.repository.getPasscode(), lock: lock)
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
                
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown)
            }
        }
    }
    
    func logInAWSUser(userPassword: String, lock: PasscodeLockType) {
        
        Pool().logIn(userEmail: emailToLogIn!, userPassword: userPassword).onLogInFailure {(task, user) in
            
            if task.error?.code == 11 {
                self.jumpToConfirmationLock(user: user, lock: lock)
            }
            
        }.onLogInSuccess {task in
            
            lock.delegate?.passcodeLockDidSucceed(lock: lock)
                
        }
    }
    
    func jumpToConfirmationLock(user: AWSCognitoIdentityUser, lock: PasscodeLockType) {
        print("Not Authenticated.")
        
        user.resendConfirmationCode()
        
        DispatchQueue.main.async {
            
            lock.changeStateTo(state: AWSCodeState(userEmail: self.emailToLogIn!, codeType: .confirmation))
        }
    }
    
    private mutating func postNotification() {
        
        guard !isNotificationSent else { return }
            
        let center = NotificationCenter.default
        
        center.post(name: NSNotification.Name(rawValue: PasscodeLockIncorrectPasscodeNotification), object: nil)
        
        isNotificationSent = true
    }
    
    // Needed to pull the email for AWS.
    func getEmail() -> String? {
        
        return emailToLogIn
    }
    
}
