//
//  ConfirmPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

struct ConfirmPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    
    private var emailToSignUp: String?
    private var passcodeToConfirm: [String]
    
    init(userEmail: String?, passcode: [String]) {
        
        emailToSignUp = userEmail
        passcodeToConfirm = passcode
        title = localizedStringFor(key: "PasscodeLockConfirmTitle", comment: "Confirm passcode title")
        description = localizedStringFor(key: "PasscodeLockConfirmDescription", comment: "Confirm passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        if passcode == passcodeToConfirm {
            
            if emailToSignUp != nil {
                self.createAWSUser(userPassword: getPasscode(), passcode: passcode, lock: lock)
            }
            else {
                passcodeConfirmSucceeded(passcode: passcode, lock: lock)
            }
        
        } else {
            
            passcodeConfirmFailed(passcode: passcode, lock: lock)
        }
    }
    
    func createAWSUser(userPassword: String, passcode: [String], lock: PasscodeLockType) {
        // AWS Send Email
        
        Pool().signUp(userEmail: emailToSignUp!, userPassword: userPassword).onSignUpFailure {task in
            
            DispatchQueue.main.async {
                
                if task.error?.code == 17 {
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock, title: "Choose a different email.", description: "That email is already taken.")
                }
                else {
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock)
                }
            }
            
        }.onSignUpSuccess {task in
            
            DispatchQueue.main.async {
                self.passcodeConfirmSucceeded(passcode: passcode, lock: lock)
            }
            
        }
    }
    
    func passcodeConfirmSucceeded(passcode: [String], lock: PasscodeLockType) {
        print("Passcode Confirm Succeeded.")
        
        lock.repository.savePasscode(passcode: passcode)
        lock.delegate?.passcodeLockDidSucceed(lock: lock)
    }
    
    func passcodeConfirmFailed(passcode: [String], lock: PasscodeLockType, title: String, description: String) {
        print("Passcode Confirm Failed.")
        
        let mismatchTitle = title
        let mismatchDescription = description
        
        let nextState = SetPasscodeState(userEmail: emailToSignUp, title: mismatchTitle, description: mismatchDescription)
        
        lock.changeStateTo(state: nextState)
        lock.delegate?.passcodeLockDidFail(lock: lock)
    }
    
    func passcodeConfirmFailed(passcode: [String], lock: PasscodeLockType) {
        print("Passcode Confirm Failed.")
        
        let mismatchTitle = localizedStringFor(key: "PasscodeLockMismatchTitle", comment: "Passcode mismatch title")
        let mismatchDescription = localizedStringFor(key: "PasscodeLockMismatchDescription", comment: "Passcode mismatch description")
        
        let nextState = SetPasscodeState(userEmail: emailToSignUp, title: mismatchTitle, description: mismatchDescription)
        
        lock.changeStateTo(state: nextState)
        lock.delegate?.passcodeLockDidFail(lock: lock)
    }
    
    // Needed to pull the passcode for AWS.
    func getPasscode() -> String {
        var passcode = ""
        
        for passcodeNum in passcodeToConfirm {
            passcode += passcodeNum
        }
        
        return passcode
    }
}
