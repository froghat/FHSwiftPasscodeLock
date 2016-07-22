//
//  Pool.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/21/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider

public class Pool {
    
    // Type aliases for AWSCognitoIdentyProvider Tasks.
    
    typealias signUpResponse = AWSTask<AWSCognitoIdentityUserPoolSignUpResponse>
    typealias logInResponse = AWSTask<AWSCognitoIdentityUserSession>
    typealias confirmationResponse = AWSTask<AWSCognitoIdentityUserConfirmSignUpResponse>
    
    // Type aliases, variables and functions handling sign ups.
    
    typealias signUpClosure = (signUpResponse) -> Void
    
    var signUpSuccessClosure: ((signUpResponse) -> ())? = nil
    var signUpFailureClosure: ((signUpResponse) -> ())? = nil
    
    func onSignUpSuccess(closure: (signUpResponse) -> ()) {
        signUpSuccessClosure = closure
    }
    
    func onSignUpFailure(closure: (signUpResponse) -> ()) -> Self {
        signUpFailureClosure = closure
        return self
    }
    
    func doSignUpSuccess(params: signUpResponse) {
        if let closure = signUpSuccessClosure {
            closure(params)
        }
    }
    
    func doSignUpFailure(params: signUpResponse) {
        if let closure = signUpFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling log ins.
    
    typealias logInClosure = (logInResponse) -> Void
    
    var logInSuccessClosure: ((logInResponse) -> ())? = nil
    var logInFailureClosure: ((logInResponse, AWSCognitoIdentityUser) -> ())? = nil
    
    func onLogInSuccess(closure: (logInResponse) -> ()) {
        logInSuccessClosure = closure
    }
    
    func onLogInFailure(closure: (logInResponse, AWSCognitoIdentityUser) -> ()) -> Self {
        logInFailureClosure = closure
        return self
    }
    
    func doLogInSuccess(params: logInResponse) {
        if let closure = logInSuccessClosure {
            closure(params)
        }
    }
    
    func doLogInFailure(param1: logInResponse, param2: AWSCognitoIdentityUser) {
        if let closure = logInFailureClosure {
            closure(param1, param2)
        }
    }
    
    // Type aliases, variables and functions handling account confirmations.
    
    typealias confirmationClosure = (confirmationResponse) -> Void
    
    var confirmationSuccessClosure: ((confirmationResponse) -> ())? = nil
    var confirmationFailureClosure: ((confirmationResponse) -> ())? = nil
    
    func onConfirmationSuccess(closure: (confirmationResponse) -> ()) {
        confirmationSuccessClosure = closure
    }
    
    func onConfirmationFailure(closure: (confirmationResponse) -> ()) -> Self {
        confirmationFailureClosure = closure
        return self
    }
    
    func doConfirmationSuccess(params: confirmationResponse) {
        if let closure = confirmationSuccessClosure {
            closure(params)
        }
    }
    
    func doConfirmationFailure(params: confirmationResponse) {
        if let closure = confirmationFailureClosure {
            closure(params)
        }
    }
    
    // AWSCognitoIdentityProvider authentication methods.
    
    let userPool: () -> AWSCognitoIdentityUserPool = {
        let serviceConfiguration = AWSServiceConfiguration(region: .usEast1, credentialsProvider: nil)
        let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: "7r9126v4vlsopi2eovtvqumfc7", clientSecret: "1jfbad1tia2vuvt9v583p4a3h4tbi3u22v2hle06sg0p97682mbd", poolId: "us-east-1_y5cEV6M8J")
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
        return AWSCognitoIdentityUserPool(forKey: "UserPool")
    }
    
    func signUp(userEmail: String, userPassword: String) -> Self {
        
        let email = AWSCognitoIdentityUserAttributeType()
        email?.name = "email"
        email?.value = userEmail
        
        // Sign the user up.
        userPool().signUp(email!.value!, password: userPassword, userAttributes: [email!], validationData: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doSignUpFailure(params: task)
            }
            else {
                print(task.result)
                
                self.doSignUpSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    // Log the user in.
    func logIn(userEmail: String, userPassword: String) -> Self {
        let user = userPool().getUser(userEmail)
        
        user.getSession(userEmail, password: userPassword, validationData: nil, scopes: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doLogInFailure(param1: task, param2: user)
                
            }
            else {
                print(task.result)
                
                self.doLogInSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    // Confirm the user's email.
    func confirm(userEmail: String, confirmationString: String) -> Self {
        let user = userPool().getUser(userEmail)
        
        user.confirmSignUp(confirmationString).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doConfirmationFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doConfirmationSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
}
