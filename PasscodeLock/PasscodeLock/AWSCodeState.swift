//
//  AWSConfirmationState.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/17/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

struct AWSCodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    
    private var codeNeeded: AWSCodeType
    
    init(codeType: AWSCodeType) {
        
        codeNeeded = codeType
        
        title = localizedStringFor(key: "PasscodeLockConfirmationTitle", comment: "Change passcode title")
        description = localizedStringFor(key: "PasscodeLockConfirmationDescription", comment: "Change passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        let confirmationString: () -> String = {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        if codeNeeded == .confirmation {
            confirmAWSUser(confirmationString: confirmationString(), lock: lock)
        }
        else if codeNeeded == .forgottenPassword {
            confirmForgottenAWSPassword(confirmationString: confirmationString(), passcode: lock.repository.getPasscode(), lock: lock)
        }
        else {
            print("Should never land here in else block of AWSCodeState.acceptPasscode.")
        }
        
    }
    
    func confirmAWSUser(confirmationString: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirm(confirmationString: confirmationString).onConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown)
            }
            
        }.onConfirmationSuccess {task in
            
            DispatchQueue.main.async {
                let nextState = EnterPasscodeState()

                lock.changeStateTo(state: nextState)
            }
            
        }
    }
    
    func confirmForgottenAWSPassword(confirmationString: String, passcode: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirmForgotPassword(confirmationString: confirmationString, passcode: passcode).onForgottenPasswordConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown)
            }
            
        }.onForgottenPasswordConfirmationSuccess {task in
                
            DispatchQueue.main.async {
                let nextState = ChangePasscodeState()
                    
                lock.changeStateTo(state: nextState)
            }
                
        }
    }
}
