//
//  AWSConfirmationState.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/17/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider
import SCLAlertView

struct AWSCodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    
    private var codeNeeded: AWSCodeType
    private var nextAction: ActionAfterConfirmation
    
    private var alert: SCLAlertViewResponder?
    
    init(codeType: AWSCodeType, priorAction: ActionAfterConfirmation = .unknown) {
        
        codeNeeded = codeType
        nextAction = priorAction
        
        print("Initializing AWS code state of type \(codeNeeded).")
        
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
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        alert = presentWaitingAlert()
        
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
                
                self.finishWaitingAlert(alert: self.alert!)
            }
        }.onVerifyAttributeSuccess {task in
            DispatchQueue.main.async {
                print("nextAction == \(self.nextAction)")
                
                if self.nextAction == .resetPassword {
                    Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                        
                        self.finishWaitingAlert(alert: self.alert!)
                        
                    }.onForgottenPasswordSuccess {task in
                        let nextState = AWSCodeState(codeType: .forgottenPassword)
                            
                        lock.changeStateTo(state: nextState)
                        
                        self.finishWaitingAlert(alert: self.alert!)
                    }
                }
                else if self.nextAction == .logIn {
                    let nextState = EnterPasscodeState()
                    
                    lock.changeStateTo(state: nextState)
                    
                    self.finishWaitingAlert(alert: self.alert!)
                }
                else {
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                    
                    self.finishWaitingAlert(alert: self.alert!)
                }
            }
        }
    }
    
    func confirmAWSUser(confirmationString: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirm(confirmationString: confirmationString).onConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: .unknown)
                
                self.finishWaitingAlert(alert: self.alert!)
            }
            
        }.onConfirmationSuccess {task in
            
            DispatchQueue.main.async {
                print("nextAction == \(self.nextAction)")
                
                if self.nextAction == .resetPassword {
                    Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                        
                        self.finishWaitingAlert(alert: self.alert!)
                        
                    }.onForgottenPasswordSuccess {task in
                        let nextState = AWSCodeState(codeType: .forgottenPassword)
                        
                        lock.changeStateTo(state: nextState)
                        
                        self.finishWaitingAlert(alert: self.alert!)
                    }
                }
                else if self.nextAction == .logIn {
                    let nextState = EnterPasscodeState()

                    lock.changeStateTo(state: nextState)
                    
                    self.finishWaitingAlert(alert: self.alert!)
                }
                else {
                    lock.delegate?.passcodeLockDidSucceed(lock: lock)
                    
                    self.finishWaitingAlert(alert: self.alert!)
                }
            }
            
        }
    }
    
    func confirmForgottenAWSPassword(confirmationString: String, passcode: String, lock: PasscodeLockType) {
        
        Pool.sharedInstance.confirmForgotPassword(confirmationString: confirmationString, passcode: passcode).onForgottenPasswordConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock, failureType: .unknown, priorAction: self.nextAction)
                
                self.finishWaitingAlert(alert: self.alert!)
            }
            
        }.onForgottenPasswordConfirmationSuccess {task in
                
            DispatchQueue.main.async {
                let nextState = SetPasscodeState(fromChange: true)
                    
                lock.changeStateTo(state: nextState)
                
                self.finishWaitingAlert(alert: self.alert!)
            }
                
        }
    }
    
    //MARK: - SCL Alert View Methods
    
    public func presentWaitingAlert() -> SCLAlertViewResponder {
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        
        let responder: SCLAlertViewResponder = SCLAlertView(appearance: appearance).showWait("Waiting for response", subTitle: "Please wait for a confirmation response from the server.")
        
        return responder
    }
    
    public func finishWaitingAlert(alert: SCLAlertViewResponder) {
        alert.close()
    }
}
