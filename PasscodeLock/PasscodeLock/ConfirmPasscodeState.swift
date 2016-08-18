//
//  ConfirmPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider
import SCLAlertView


struct ConfirmPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    let changingPasscode: Bool
    
    private var passcodeToConfirm: [String]
    
    private var alert: SCLAlertViewResponder?
    
    init(passcode: [String], fromChange: Bool = false) {
        passcodeToConfirm = passcode
        changingPasscode = fromChange
        print("Changing Passcode = \(changingPasscode)")
        title = localizedStringFor(key: "PasscodeLockConfirmTitle", comment: "Confirm passcode title")
        description = localizedStringFor(key: "PasscodeLockConfirmDescription", comment: "Confirm passcode description")
    }
    
    mutating func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        alert = presentWaitingAlert()
        
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
    
    mutating func registerIncorrectPasscode(lock: PasscodeLockType) -> Bool {return false} // Not needed for this state type
    
    func createAWSUser(userPassword: String, passcode: [String], lock: PasscodeLockType) {
        // AWS Send Email
        
        Pool.sharedInstance.signUp(userPassword: userPassword).onSignUpFailure {task in
            
            DispatchQueue.main.async {
                
                if task.error?._code == 17 || task.error?._code == 25 {
                    print("User's requested email is already taken.")
                    
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .emailTaken, title: "Choose a different email.", description: "That email is already taken.")
                }
                else {
                    print("Sign up failed for unknown reason.")
                    
                    self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .unknown)
                }
                
                self.finishWaitingAlert(alert: self.alert!)
            }
            
        }.onSignUpSuccess {task in
            
            DispatchQueue.main.async {
                
                Pool.sharedInstance.logIn(userPassword: userPassword).onLogInFailure {task in
                    
                    self.finishWaitingAlert(alert: self.alert!)
                    
                }.onLogInSuccess {task in
                    
                    Pool.sharedInstance.user?.getAttributeVerificationCode("email")
                    
                    lock.changeStateTo(state: AWSCodeState(codeType: .attributeVerification))
                    
                    self.finishWaitingAlert(alert: self.alert!)
                        
                }
            }
            
        }
    }
    
    func changeAWSPassword(currentPassword: String, proposedPassword: String, passcode: [String], lock: PasscodeLockType) {
        
        Pool.sharedInstance.changePassword(currentPassword: currentPassword, proposedPassword: proposedPassword).onChangePasswordFailure {task in
            if task.error?._code == 11 {
                
                self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .notConfirmed)
                
            } else {
                print(task.error?._code)
                self.passcodeConfirmFailed(passcode: passcode, lock: lock, failureType: .unknown)
                
            }
            
            self.finishWaitingAlert(alert: self.alert!)
            
        }.onChangePasswordSuccess {task in
            DispatchQueue.main.async {
                self.passcodeConfirmSucceeded(passcode: passcode, lock: lock)
                
                Pool.sharedInstance.logIn(userPassword: proposedPassword).onLogInFailure {task in
                    
                    self.finishWaitingAlert(alert: self.alert!)
                    
                }.onLogInSuccess {task in
                    
                    self.finishWaitingAlert(alert: self.alert!)
                        
                }
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
        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: failureType, priorAction: .unknown)
    }
    
    func passcodeConfirmFailed(passcode: [String], lock: PasscodeLockType, failureType: FailureType) {
        print("Passcode Confirm Failed.")
        
        let mismatchTitle = localizedStringFor(key: "PasscodeLockMismatchTitle", comment: "Passcode mismatch title")
        let mismatchDescription = localizedStringFor(key: "PasscodeLockMismatchDescription", comment: "Passcode mismatch description")
        		
        let nextState = SetPasscodeState(title: mismatchTitle, description: mismatchDescription)
        
        lock.changeStateTo(state: nextState)
        lock.delegate?.passcodeLockDidFail(lock: lock, failureType: failureType, priorAction: .unknown)
    }
    
    // Needed to pull the passcode for AWS.
    func getPasscode() -> String {
        var passcode = ""
        
        for passcodeNum in passcodeToConfirm {
            passcode += passcodeNum
        }
        
        return passcode
    }
    
    //MARK: - SCL Alert View Methods
    
    public func presentWaitingAlert() -> SCLAlertViewResponder {
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        
        let responder: SCLAlertViewResponder = SCLAlertView(appearance: appearance).showWait("Waiting for response", subTitle: "Please wait for a sign up response from the server.")
        
        return responder
    }
    
    public func finishWaitingAlert(alert: SCLAlertViewResponder) {
        alert.close()
    }
}
