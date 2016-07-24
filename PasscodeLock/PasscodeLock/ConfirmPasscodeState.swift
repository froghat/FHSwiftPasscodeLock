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
    let changingPasscode: Bool
    
    private var passcodeToConfirm: [String]
    
    init(passcode: [String], fromChange: Bool = false) {
        passcodeToConfirm = passcode
        changingPasscode = fromChange
        print("Changing Passcode = \(changingPasscode)")
        title = localizedStringFor(key: "PasscodeLockConfirmTitle", comment: "Confirm passcode title")
        description = localizedStringFor(key: "PasscodeLockConfirmDescription", comment: "Confirm passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        if passcode == passcodeToConfirm {
            
            if Pool.sharedInstance.user != nil {
                if changingPasscode == false {
                    self.createAWSUser(userPassword: getPasscode(), passcode: passcode, lock: lock)
                }
                else {
                    self.changeAWSPassword(currentPassword: lock.repository.getPasscode(), proposedPassword: getPasscode(), passcode: passcode, lock: lock)
                }
            }
            else {
                passcodeConfirmSucceeded(passcode: passcode, lock: lock)
            }
        
        } else {
            
            passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .incorrectPasscode)
        }
    }
    
    func createAWSUser(userPassword: String, passcode: [String], lock: PasscodeLockType) {
        // AWS Send Email
        
        Pool.sharedInstance.signUp(userPassword: userPassword).onSignUpFailure {task in
            
            DispatchQueue.main.async {
                
                if task.error?.code == 17 {
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .emailTaken, title: "Choose a different email.", description: "That email is already taken.")
                }
                else {
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .unknown)
                }
            }
            
        }.onSignUpSuccess {task in
            
            DispatchQueue.main.async {
                self.passcodeConfirmSucceeded(passcode: passcode, lock: lock)
            }
            
        }
    }
    
    func changeAWSPassword(currentPassword: String, proposedPassword: String, passcode: [String], lock: PasscodeLockType) {
        
        Pool.sharedInstance.changePassword(currentPassword: currentPassword, proposedPassword: proposedPassword).onChangePasswordFailure {task in
            if task.error?.code == 11 {
                
                self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .notConfirmed)
                
            } else {
                print(task.error?.code)
                self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .unknown)
                
            }
            
        }.onChangePasswordSuccess {task in
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
    
    func passcodeConfirmFailed(passcode: [String], lock: PasscodeLockType, failureType: FailureType, title: String, description: String) {
        print("Passcode Confirm Failed.")
        
        let mismatchTitle = title
        let mismatchDescription = description
        
        let nextState = SetPasscodeState(title: mismatchTitle, description: mismatchDescription)
        
        lock.changeStateTo(state: nextState)
        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: failureType)
    }
    
    func passcodeConfirmFailed(passcode: [String], lock: PasscodeLockType, failureType: FailureType) {
        print("Passcode Confirm Failed.")
        
        let mismatchTitle = localizedStringFor(key: "PasscodeLockMismatchTitle", comment: "Passcode mismatch title")
        let mismatchDescription = localizedStringFor(key: "PasscodeLockMismatchDescription", comment: "Passcode mismatch description")
        		
        let nextState = SetPasscodeState(title: mismatchTitle, description: mismatchDescription)
        
        lock.changeStateTo(state: nextState)
        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: failureType)
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
