//
//  Enums.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/22/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

public enum ActionAfterConfirmation: Int, CustomStringConvertible {
    case unknown = 0, resetPassword, logIn
    
    var TypeName: String {
        let typeNames = [
            "Unknown",
            "Reset Password",
            "Log In"]
        return typeNames[rawValue]
    }
    
    public var description: String {
        return TypeName
    }
}

public func ==(lhs: ActionAfterConfirmation, rhs: ActionAfterConfirmation) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

public enum AWSCodeType: Int, CustomStringConvertible {
    case unknown = 0, confirmation, forgottenPassword
    
    var TypeName: String {
        let typeNames = [
            "Unknown",
            "Confirmation Needed",
            "Password Forgotten"]
        return typeNames[rawValue]
    }
    
    public var description: String {
        return TypeName
    }
}

public func ==(lhs: AWSCodeType, rhs: AWSCodeType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

public enum FailureType: Int, CustomStringConvertible {
    case unknown = 0, emailTaken, notConfirmed, invalidEmail, incorrectPasscode
    
    var TypeName: String {
        let typeNames = [
            "Unknown",
            "Email Taken",
            "User uncomfirmed",
            "Invalid Email",
            "Incorrect Passcode"]
        return typeNames[rawValue]
    }
    
    public var description: String {
        return TypeName
    }
}

public func ==(lhs: FailureType, rhs: FailureType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}
