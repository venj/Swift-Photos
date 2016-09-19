//
//  PasscodeLockConfiguration.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/29/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import Foundation
import PasscodeLock

struct PasscodeLockConfiguration: PasscodeLockConfigurationType {
    let repository: PasscodeRepositoryType
    let passcodeLength = 4
    var isTouchIDAllowed = true
    let shouldRequestTouchIDImmediately = true
    let maximumInccorectPasscodeAttempts = -1
    var touchIdReason: String? = NSLocalizedString("Swift Photos needs your finger print to protect your content.", comment: "Swift Photos needs your finger print to protect your content.")
    
    init(repository: PasscodeRepositoryType) {
        self.repository = repository
    }
    
    init() {
        self.repository = UserDefaultsPasscodeRepository()
    }
}
