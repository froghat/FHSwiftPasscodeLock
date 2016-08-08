//
//  UserDefaultsPasscodeRepository.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/29/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import JNKeychain

class UserDefaultsPasscodeRepository: PasscodeRepositoryType {
    
    private let usernameKey = "passcode.lock.username"
    private let passcodeKey = "passcode.lock.passcode"
    
    private lazy var defaults: UserDefaults = {
        
        return UserDefaults.standard
    }()
    
    var hasPasscode: Bool {
        
        if passcode != nil {
            return true
        }
        
        return false
    }
    
    var passcode: [String]? {
        
        //return defaults.value(forKey: passcodeKey) as? [String] ?? nil
        return JNKeychain.loadValue(forKey: passcodeKey) as? [String] ?? nil
    }
    
    func savePasscode(passcode: [String]) {
        
        print("Attempting to save passcode to keychain.")
        print("Current value is \(JNKeychain.loadValue(forKey: passcodeKey))")
        if JNKeychain.saveValue(passcode, forKey: passcodeKey) {
            print ("Passcode \(passcode) saved for key \(passcodeKey).")
        }
        else {
            print ("Passcode \(passcode) save failed for key \(passcodeKey). Shieeet")
        }
        
        defaults.set(true, forKey: "hasLoginKey")
        defaults.synchronize()
    }
    
    func deletePasscode() {
        
        if JNKeychain.deleteValue(forKey: passcodeKey) {
            print ("Passcode \(passcode) deleted for key \(passcodeKey).")
        }
        else {
            print ("Passcode \(passcode) delete failed for key \(passcodeKey).")
        }
        
        defaults.set(false, forKey: "hasLoginKey")
        defaults.synchronize()
    }
    
    func getPasscode() -> String {
        var passcodeToGet = ""
        if passcode != nil {
            for passcodeNum in passcode! {
                passcodeToGet += passcodeNum
            }
            return passcodeToGet
        }
        else {
            return "Error"
        }
    }
}
