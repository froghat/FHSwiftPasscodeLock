//
//  Pool.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/21/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation
import AWSCognito
import AWSCognitoIdentityProvider

let AWS_EMAIL_KEY = "awsEmailKey"

public class Pool {
    
    // Make class usable as a singleton This is so we can set a delegate for the user pool and maintain it.
    
    public static let sharedInstance = Pool()
    
    private init() {} // This prevents others from using the default '()' initializer.
    
    // Email and user objects necessary for the AWS methods.
    
    private var userEmail: String? = nil
    
    internal var userPool: AWSCognitoIdentityUserPool? = nil
    
    internal var user: AWSCognitoIdentityUser? = nil
    
    // Method to set the email when a PasscodeLock is created.
    
    public func setEmail(email: String) {
        print("Setting email to \(email)")
        
        userEmail = email
        
        print("Setting user to \(userPool?.getUser(email))")
        
        user = userPool?.getUser(email)
        
        // Set the default email so a user can login from app opening.
        print("Setting default email to \(email)")
        
        UserDefaults.standard.set(email, forKey: AWS_EMAIL_KEY)
    }
    
    // Method to set the userPool in AppDelegate.
    
    public func setUserPool(region: AWSRegionType, identityPoolID: String, credentialsProvider: AWSCredentialsProvider?, clientID: String, clientSecret: String?, poolID: String) {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: region, identityPoolId: identityPoolID)
        let serviceConfiguration = AWSServiceConfiguration(region: region, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = serviceConfiguration
        
        
        
        credentialsProvider.credentials().continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
            }
            else {
                print(task.result)
            }
            
            return nil
        })
        
        let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: clientID, clientSecret: clientSecret, poolId: poolID)
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
        let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
        self.userPool = pool
        
//        let syncClient = AWSCognito.default()
//        let dataset = syncClient?.openOrCreateDataset("myDataset")
//        dataset?.setString("myValue", forKey: "myKey")
//        dataset?.synchronize().continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
//            //Your handler code here
//            return nil
//        })
    }
    
    // Type aliases for AWSCognitoIdentyProvider Tasks.
    
    typealias SignUpResponse = AWSTask<AWSCognitoIdentityUserPoolSignUpResponse>
    typealias LogInResponse = AWSTask<AWSCognitoIdentityUserSession>
    typealias ConfirmationResponse = AWSTask<AWSCognitoIdentityUserConfirmSignUpResponse>
    typealias ChangePasswordResponse = AWSTask<AWSCognitoIdentityUserChangePasswordResponse>
    typealias ForgottenPasswordResponse = AWSTask<AWSCognitoIdentityUserForgotPasswordResponse>
    typealias ForgottenPasswordConfirmationResponse = AWSTask<AWSCognitoIdentityUserConfirmForgotPasswordResponse>
    typealias VerifyAttributeResponse = AWSTask<AWSCognitoIdentityUserVerifyAttributeResponse>
    typealias UserDetailsResponse = AWSTask<AWSCognitoIdentityUserGetDetailsResponse>
    
    // Type aliases, variables and functions handling sign ups.
    
    typealias SignUpClosure = (SignUpResponse) -> Void
    
    var signUpSuccessClosure: ((SignUpResponse) -> ())? = nil
    var signUpFailureClosure: ((SignUpResponse) -> ())? = nil
    
    func onSignUpSuccess(closure: (SignUpResponse) -> ()) {
        signUpSuccessClosure = closure
    }
    
    func onSignUpFailure(closure: (SignUpResponse) -> ()) -> Self {
        signUpFailureClosure = closure
        return self
    }
    
    func doSignUpSuccess(params: SignUpResponse) {
        if let closure = signUpSuccessClosure {
            closure(params)
        }
    }
    
    func doSignUpFailure(params: SignUpResponse) {
        if let closure = signUpFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling log ins.
    
    typealias LogInClosure = (LogInResponse) -> Void
    
    var logInSuccessClosure: ((LogInResponse) -> ())? = nil
    var logInFailureClosure: ((LogInResponse) -> ())? = nil
    
    func onLogInSuccess(closure: (LogInResponse) -> ()) {
        logInSuccessClosure = closure
    }
    
    func onLogInFailure(closure: (LogInResponse) -> ()) -> Self {
        logInFailureClosure = closure
        return self
    }
    
    func doLogInSuccess(params: LogInResponse) {
        if let closure = logInSuccessClosure {
            closure(params)
        }
    }
    
    func doLogInFailure(params: LogInResponse) {
        if let closure = logInFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling account confirmations.
    
    typealias ConfirmationClosure = (ConfirmationResponse) -> Void
    
    var confirmationSuccessClosure: ((ConfirmationResponse) -> ())? = nil
    var confirmationFailureClosure: ((ConfirmationResponse) -> ())? = nil
    
    func onConfirmationSuccess(closure: (ConfirmationResponse) -> ()) {
        confirmationSuccessClosure = closure
    }
    
    func onConfirmationFailure(closure: (ConfirmationResponse) -> ()) -> Self {
        confirmationFailureClosure = closure
        return self
    }
    
    func doConfirmationSuccess(params: ConfirmationResponse) {
        if let closure = confirmationSuccessClosure {
            closure(params)
        }
    }
    
    func doConfirmationFailure(params: ConfirmationResponse) {
        if let closure = confirmationFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling password changes.
    
    typealias ChangePasswordClosure = (ChangePasswordResponse) -> Void
    
    var changePasswordSuccessClosure: ((ChangePasswordResponse) -> ())? = nil
    var changePasswordFailureClosure: ((ChangePasswordResponse) -> ())? = nil
    
    func onChangePasswordSuccess(closure: (ChangePasswordResponse) -> ()) {
        changePasswordSuccessClosure = closure
    }
    
    func onChangePasswordFailure(closure: (ChangePasswordResponse) -> ()) -> Self {
        changePasswordFailureClosure = closure
        return self
    }
    
    func doChangePasswordSuccess(params: ChangePasswordResponse) {
        if let closure = changePasswordSuccessClosure {
            closure(params)
        }
    }
    
    func doChangePasswordFailure(params: ChangePasswordResponse) {
        if let closure = changePasswordFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling forgotten passwords.
    
    typealias ForgottenPasswordClosure = (ForgottenPasswordResponse) -> Void
    
    var forgottenPasswordSuccessClosure: ((ForgottenPasswordResponse) -> ())? = nil
    var forgottenPasswordFailureClosure: ((ForgottenPasswordResponse) -> ())? = nil
    
    func onForgottenPasswordSuccess(closure: (ForgottenPasswordResponse) -> ()) {
        forgottenPasswordSuccessClosure = closure
    }
    
    func onForgottenPasswordFailure(closure: (ForgottenPasswordResponse) -> ()) -> Self {
        forgottenPasswordFailureClosure = closure
        return self
    }
    
    func doForgottenPasswordSuccess(params: ForgottenPasswordResponse) {
        if let closure = forgottenPasswordSuccessClosure {
            closure(params)
        }
    }
    
    func doForgottenPasswordFailure(params: ForgottenPasswordResponse) {
        if let closure = forgottenPasswordFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling forgotten passwords.
    
    typealias ForgottenPasswordConfirmationClosure = (ForgottenPasswordConfirmationResponse) -> Void
    
    var forgottenPasswordConfirmationSuccessClosure: ((ForgottenPasswordConfirmationResponse) -> ())? = nil
    var forgottenPasswordConfirmationFailureClosure: ((ForgottenPasswordConfirmationResponse) -> ())? = nil
    
    func onForgottenPasswordConfirmationSuccess(closure: (ForgottenPasswordConfirmationResponse) -> ()) {
        forgottenPasswordConfirmationSuccessClosure = closure
    }
    
    func onForgottenPasswordConfirmationFailure(closure: (ForgottenPasswordConfirmationResponse) -> ()) -> Self {
        forgottenPasswordConfirmationFailureClosure = closure
        return self
    }
    
    func doForgottenPasswordConfirmationSuccess(params: ForgottenPasswordConfirmationResponse) {
        if let closure = forgottenPasswordConfirmationSuccessClosure {
            closure(params)
        }
    }
    
    func doForgottenPasswordConfirmationFailure(params: ForgottenPasswordConfirmationResponse) {
        if let closure = forgottenPasswordConfirmationFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling attribute verification.
    
    typealias VerifyAttributeConfirmationClosure = (VerifyAttributeResponse) -> Void
    
    var verifyAttributeSuccessClosure: ((VerifyAttributeResponse) -> ())? = nil
    var verifyAttributeFailureClosure: ((VerifyAttributeResponse) -> ())? = nil
    
    func onVerifyAttributeSuccess(closure: (VerifyAttributeResponse) -> ()) {
        verifyAttributeSuccessClosure = closure
    }
    
    func onVerifyAttributeFailure(closure: (VerifyAttributeResponse) -> ()) -> Self {
        verifyAttributeFailureClosure = closure
        return self
    }
    
    func doVerifyAttributeSuccess(params: VerifyAttributeResponse) {
        if let closure = verifyAttributeSuccessClosure {
            closure(params)
        }
    }
    
    func doVerifyAttributeFailure(params: VerifyAttributeResponse) {
        if let closure = verifyAttributeFailureClosure {
            closure(params)
        }
    }
    
    // Type aliases, variables and functions handling user details responses.
    
    typealias UserDetailsClosure = (UserDetailsResponse) -> Void
    
    var userDetailsSuccessClosure: ((UserDetailsResponse) -> ())? = nil
    var userDetailsFailureClosure: ((UserDetailsResponse) -> ())? = nil
    
    func onUserDetailsSuccess(closure: (UserDetailsResponse) -> ()) {
        userDetailsSuccessClosure = closure
    }
    
    func onUserDetailsFailure(closure: (UserDetailsResponse) -> ()) -> Self {
        userDetailsFailureClosure = closure
        return self
    }
    
    func doUserDetailsSuccess(params: UserDetailsResponse) {
        if let closure = userDetailsSuccessClosure {
            closure(params)
        }
    }
    
    func doUserDetailsFailure(params: UserDetailsResponse) {
        if let closure = userDetailsFailureClosure {
            closure(params)
        }
    }
    
    // AWSCognitoIdentityProvider authentication methods.
    
    func signUp(userPassword: String) -> Self {
        
        let email = AWSCognitoIdentityUserAttributeType()
        email?.name = "email"
        email?.value = userEmail
        
        // Sign the user up.
        userPool?.signUp(email!.value!, password: userPassword, userAttributes: [email!], validationData: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doSignUpFailure(params: task)
            }
            else {
                print(task.result)
                
                self.doSignUpSuccess(params: task)
                
                self.user = self.userPool?.getUser(self.userEmail!)
            }
            
            return nil
        })
        
        return self
    }
    
    // Log the user in.
    func logIn(userPassword: String) -> Self {
        
        user?.getSession(userEmail!, password: userPassword, validationData: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doLogInFailure(params: task)
                
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
    func confirm(confirmationString: String) -> Self {
        
        user?.confirmSignUp(confirmationString).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
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
    
    func forgotPassword() -> Self {
        print(user?.getDetails())
        
        user?.forgotPassword().continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error!)
                
                self.doForgottenPasswordFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doForgottenPasswordSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    func confirmForgotPassword(confirmationString: String, passcode: String) -> Self {
        
        user?.confirmForgotPassword(confirmationString, password: passcode).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error!)
                
                self.doForgottenPasswordConfirmationFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doForgottenPasswordConfirmationSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    func changePassword(currentPassword: String, proposedPassword: String) -> Self {
        
        user?.changePassword(currentPassword, proposedPassword: proposedPassword).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doChangePasswordFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doChangePasswordSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    func verifyUserAtrribute(attribute: String, code: String) -> Self {
        user?.verifyAttribute(attribute, code: code).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doVerifyAttributeFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doVerifyAttributeSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
    
    func getUserDetails() -> Self {
        user?.getDetails().continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
            
            if task.error != nil {
                print(task.error!)
                
                self.doUserDetailsFailure(params: task)
                
            }
            else {
                print(task.result)
                
                self.doUserDetailsSuccess(params: task)
            }
            
            return nil
        })
        
        return self
    }
}
