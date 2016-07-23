//
//  Enums.swift
//  PasscodeLock
//
//  Created by Ian Hanken on 7/22/16.
//  Copyright © 2016 Yanko Dimitrov. All rights reserved.
//

import Foundation

public enum FailureType: Int, CustomStringConvertible {
    case unknown = 0, emailTaken, wrongCredentials, incorrectPasscode, notConfirmed
    
    var TypeName: String {
        let typeNames = [
            "Unknown",
            "Email Taken",
            "Wrong Credentials",
            "Incorrect Passcode",
            "User uncomfirmed"]
        return typeNames[rawValue]
    }
    
    public var description: String {
        return TypeName
    }
}

public func ==(lhs: FailureType, rhs: FailureType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}
