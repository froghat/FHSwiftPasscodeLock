//
//  SetPasscodeState.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation

struct SetPasscodeState: PasscodeLockStateType {
    
    let title: String
    let description: String
    let isCancellableAction = true
    var isTouchIDAllowed = false
    let changingPasscode: Bool
    
    private var email: String?
    
    init(userEmail: String?, fromChange: Bool = false, title: String, description: String) {
        
        self.email = userEmail
        changingPasscode = fromChange
        
        self.title = title
        self.description = description
    }
    
    init(userEmail: String?, fromChange: Bool = false) {
        email = userEmail
        changingPasscode = fromChange
        
        title = localizedStringFor(key: "PasscodeLockSetTitle", comment: "Set passcode title")
        description = localizedStringFor(key: "PasscodeLockSetDescription", comment: "Set passcode description")
    }
    
    init() {
        email = nil
        changingPasscode = false
        
        title = localizedStringFor(key: "PasscodeLockSetTitle", comment: "Set passcode title")
        description = localizedStringFor(key: "PasscodeLockSetDescription", comment: "Set passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        let nextState = ConfirmPasscodeState(userEmail: self.email, passcode: passcode, fromChange: changingPasscode)
        
        lock.changeStateTo(state: nextState)
    }
    
    // Needed to pull the email for AWS.
    func getEmail() -> String? {
        
        return email
    }
}
