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
    
    init(fromChange: Bool = false, title: String, description: String) {
        
        changingPasscode = fromChange
        
        self.title = title
        self.description = description
    }
    
    
    
    init(fromChange: Bool = false) {
        
        changingPasscode = fromChange
        
        title = localizedStringFor(key: "PasscodeLockSetTitle", comment: "Set passcode title")
        description = localizedStringFor(key: "PasscodeLockSetDescription", comment: "Set passcode description")
    }
    
    func acceptPasscode(passcode: [String], fromLock lock: PasscodeLockType) {
        
        let nextState = ConfirmPasscodeState(passcode: passcode, fromChange: changingPasscode)
        
        lock.changeStateTo(state: nextState)
    }
    
    mutating func registerIncorrectPasscode(lock: PasscodeLockType) -> Bool {return false} // Not needed for this state type
}
