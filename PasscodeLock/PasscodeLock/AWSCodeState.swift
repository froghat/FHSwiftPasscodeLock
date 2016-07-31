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
    private var nextAction: ActionAfterConfirmation
    
    init(codeType: AWSCodeType, priorAction: ActionAfterConfirmation = .unknown) {
        
        codeNeeded = codeType
        nextAction = priorAction
        
        if codeType == .attributeVerification {
            title = "Verify Email"
            description = "Please enter the verification code in your email."
        }
        else if codeType == .confirmation {
            title = "Confirm Email"
            description = "Please enter the verification code in your email."
        }
        else {
            title = "Enter Code to Reset Password"
            description = "Please enter the verification code in your email."
        }
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        let confirmationString: () -> String = {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        
        if codeNeeded == .attributeVerification {
            verifyAWSAttribute(attribute: "email", code: confirmationString(), lock: lock)
        }
        else if codeNeeded == .confirmation {
            confirmAWSUser(confirmationString: confirmationString(), lock: lock)
        }
        else if codeNeeded == .forgottenPassword {
            confirmForgottenAWSPassword(confirmationString: confirmationString(), passcode: lock.repository.getPasscode(), lock: lock)
        }
        else {
            print("Should never land here in else block of AWSCodeState.acceptPasscode.")
        }
        
    }
    
    mutating func registerIncorrectPasscode(lock: PasscodeLockType) -> Bool {return false} // Not needed for this state type
    
    func verifyAWSAttribute(attribute: String, code: String, lock: PasscodeLockType) {
        Pool.sharedInstance.verifyUserAtrribute(attribute: attribute, code: code).onVerifyAttributeFailure {task in
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
        }.onVerifyAttributeSuccess {task in
            DispatchQueue.main.async {
                print("nextAction == \(self.nextAction)")
                
                if self.nextAction == .resetPassword {
                    Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                        
                        }.onForgottenPasswordSuccess {task in
                            let nextState = AWSCodeState(codeType: .forgottenPassword)
                            
                            lock.changeStateTo(state: nextState)
                    }
                }
                else if self.nextAction == .logIn {
                    let nextState = EnterPasscodeState()
                    
                    lock.changeStateTo(state: nextState)
                }
                else {
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                }
            }
        }
    }
    
    func confirmAWSUser(confirmationString: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirm(confirmationString: confirmationString).onConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
            }
            
        }.onConfirmationSuccess {task in
            
            DispatchQueue.main.async {
                print("nextAction == \(self.nextAction)")
                
                if self.nextAction == .resetPassword {
                    Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                        
                    }.onForgottenPasswordSuccess {task in
                        let nextState = AWSCodeState(codeType: .forgottenPassword)
                        
                        lock.changeStateTo(state: nextState)
                    }
                }
                else if self.nextAction == .logIn {
                    let nextState = EnterPasscodeState()

                    lock.changeStateTo(state: nextState)
                }
                else {
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                }
            }
            
        }
    }
    
    func confirmForgottenAWSPassword(confirmationString: String, passcode: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirmForgotPassword(confirmationString: confirmationString, passcode: passcode).onForgottenPasswordConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: self.nextAction)
            }
            
        }.onForgottenPasswordConfirmationSuccess {task in
                
            DispatchQueue.main.async {
                let nextState = SetPasscodeState(fromChange: true)
                    
                lock.changeStateTo(state: nextState)
            }
                
        }
    }
}
