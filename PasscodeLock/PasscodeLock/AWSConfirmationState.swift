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
        
//        guard let currentPasscode = lock.repository.passcode else {
//            return
//        }
//        
//        if passcode == currentPasscode {
//            
//            let nextState = SetPasscodeState()
//            
//            lock.changeStateTo(state: nextState)
//            
//        } else {
//            
//            lock.delegate?.passcodeLockDidFail(lock: lock)
//        }
        
        let serviceConfiguration = AWSServiceConfiguration(region: .usEast1, credentialsProvider: nil)
        let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: "7r9126v4vlsopi2eovtvqumfc7", clientSecret: "1jfbad1tia2vuvt9v583p4a3h4tbi3u22v2hle06sg0p97682mbd", poolId: "us-east-1_y5cEV6M8J")
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
        let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
        _ = AWSCognitoCredentialsProvider(regionType: .usEast1, identityPoolId: "us-east-1_y5cEV6M8J", identityProviderManager:pool)
        
        let user = pool.getUser(email)
        
        let confirmationString: () -> String = {
            var str = ""
            
            for char in passcode {
                str += char
            }
            
            return str
        }
        
        user.confirmSignUp(confirmationString()).continue(successBlock: {(task: AWSTask<AWSCognitoIdentityUserConfirmSignUpResponse>) -> AnyObject? in
            if task.error != nil {
                print(task.error!)
                
                DispatchQueue.main.async {
                    lock.delegate?.passcodeLockDidFail(lock: lock)
                }
            }
            else {
                print(task.result)
                
                DispatchQueue.main.async {
                    let nextState = EnterPasscodeState()
                    
                    lock.changeStateTo(state: nextState)
                }
            }
            
            return nil
        })
        
    }
}
