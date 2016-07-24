//
//  Enums.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/22/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

public enum FailureType: Int, CustomStringConvertible {
    case unknown = 0, emailTaken, notConfirmed, wrongCredentials, incorrectPasscode
    
    var TypeName: String {
        let typeNames = [
            "Unknown",
            "Email Taken",
            "User uncomfirmed",
            "Wrong Credentials",
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
