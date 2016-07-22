//
//  AWSConfirmationState.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/17/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

struct AWSConfirmationState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    
    private var email: String
    
    init(userEmail: String) {
        
        email = userEmail
        title = localizedStringFor(key: "PasscodeLockChangeTitle", comment: "Change passcode title")
        description = localizedStringFor(key: "PasscodeLockChangeDescription", comment: "Change passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        let confirmationString: () -> String = {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        confirmAWSUser(confirmationString: confirmationString(), lock: lock)
        
    }
    
    func confirmAWSUser(confirmationString: String, lock: PasscodeLockType) {
        
        Pool().confirm(userEmail: email, confirmationString: confirmationString).onConfirmationFailure {task in
            
            DispatchQueue.main.async {
                lock.delegate?.passcodeLockDidFail(lock: lock)
            }
            
        }.onConfirmationSuccess {task in
            
            DispatchQueue.main.async {
                let nextState = EnterPasscodeState(userEmail: self.email)

                lock.changeStateTo(state: nextState)
            }
            
        }
    }
}
