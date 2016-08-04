//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit
import AWSCore
import AWSCognitoIdentityProvider
import SCLAlertView

extension String {
    
    //To check text field or String is blank or not
    var isBlank: Bool {
        get {
            let trimmed = trimmingCharacters(in: NSCharacterSet.whitespaces)
            return trimmed.isEmpty
        }
    }
    
    //Validate Email
    var isEmail: Bool {
        // print("validate calendar: \(testStr)")
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: self)
    }
    
    //validate PhoneNumber
    var isPhoneNumber: Bool {
        
        let charcter = NSCharacterSet(charactersIn: "+0123456789").inverted
        
        var filtered:NSString!
        
        let inputString: NSArray = self.components(separatedBy: charcter)
        
        filtered = inputString.componentsJoined(by: "")
        return  self == filtered
        
    }
}

public class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate, AWSCognitoIdentityInteractiveAuthenticationDelegate, AWSCognitoIdentityPasswordAuthentication, AWSCognitoIdentityMultiFactorAuthentication {
    
    public var page = 0
    
    public enum LockState {
        case EnterPasscode
        case SetPasscode
        case ChangePasscode
        case RemovePasscode
        case AWSCode(codeType: AWSCodeType)
        
        func getState() -> PasscodeLockStateType {
            
            switch self {
                case .EnterPasscode: return EnterPasscodeState()
                case .SetPasscode: return SetPasscodeState()
                case .ChangePasscode: return ChangePasscodeState()
                case .RemovePasscode: return EnterPasscodeState(allowCancellation: true)
                case .AWSCode(let codeType): return AWSCodeState(codeType: codeType)
            }
        }
    }
    
    @IBOutlet public weak var titleLabel: UILabel?
    @IBOutlet public weak var descriptionLabel: UILabel?
    @IBOutlet public var placeholders: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
    @IBOutlet public weak var cancelButton: UIButton?
    @IBOutlet public weak var deleteSignButton: UIButton?
    @IBOutlet public weak var touchIDButton: UIButton?
    @IBOutlet public weak var viewIntroductionButton: UIButton?
    @IBOutlet public weak var placeholdersX: NSLayoutConstraint?
    
    public var successCallback: ((lock: PasscodeLockType) -> Void)?
    public var dismissCompletionCallback: (()->Void)?
    public var animateOnDismiss: Bool
    public var notificationCenter: NotificationCenter?
    public var passedEmail: String?
    
    internal let passcodeConfiguration: PasscodeLockConfigurationType
    internal let passcodeLock: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted = true
    internal var isConfirmation = false
    
    private var shouldTryToAuthenticateWithBiometrics = true
    
    private var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    // MARK: - Initializers
    
    public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true) {
        
        self.animateOnDismiss = animateOnDismiss
        
        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        
        let nibName = "PasscodeLockView"
        let bundle: Bundle = bundleForResource(name: nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundle)
        
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
    }
    
    public convenience init(state: LockState, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true) {
        
        self.init(state: state.getState(), configuration: configuration, animateOnDismiss: animateOnDismiss)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
        clearEvents()
    }
    
    // MARK: - View
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        Pool.sharedInstance.userPool?.delegate = self
        Pool.sharedInstance.setEmail(email: passedEmail!)
        
        updatePasscodeView()
        deleteSignButton?.isEnabled = false
        
        setupEvents()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldTryToAuthenticateWithBiometrics {
        
            authenticateWithBiometrics()
        }
    }
    
    internal func updatePasscodeView() {
        
        titleLabel?.text = passcodeLock.state.title
        descriptionLabel?.text = passcodeLock.state.description
        cancelButton?.isHidden = !passcodeLock.state.isCancellableAction
        touchIDButton?.isHidden = !passcodeLock.isTouchIDAllowed
    }
    
    // MARK: - Events
    
    private func setupEvents() {
        
        notificationCenter?.addObserver(self, selector: #selector(self.appWillEnterForegroundHandler(notification:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.addObserver(self, selector: #selector(self.appDidEnterBackgroundHandler(notification:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    private func clearEvents() {
        
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    public func appWillEnterForegroundHandler(notification: NSNotification) {
        
        authenticateWithBiometrics()
    }
    
    public func appDidEnterBackgroundHandler(notification: NSNotification) {
        
        shouldTryToAuthenticateWithBiometrics = false
    }
    
    // MARK: - Actions
    
    @IBAction func passcodeSignButtonTap(_ sender: PasscodeSignButton) {
        guard isPlaceholdersAnimationCompleted else { return }
        
        passcodeLock.addSign(sign: sender.passcodeSign)
    }
    
    @IBAction func cancelButtonTap(_ sender: UIButton) {
        
        dismissPasscodeLock(lock: passcodeLock)
    }
    
    @IBAction func deleteSignButtonTap(_ sender: UIButton) {
        
        passcodeLock.removeSign()
    }
    
    @IBAction func touchIDButtonTap(_ sender: UIButton) {
        
        passcodeLock.authenticateWithBiometrics()
    }
    
    @IBAction func viewIntroductionButtonTap(_ sender: UIButton) {
        
        self.dismissPasscodeLock(lock: passcodeLock)
    }
    
    private func authenticateWithBiometrics() {
        
        if passcodeConfiguration.shouldRequestTouchIDImmediately && passcodeLock.isTouchIDAllowed {
            
            passcodeLock.authenticateWithBiometrics()
        }
    }
    
    internal func dismissPasscodeLock(lock: PasscodeLockType, completionHandler: (() -> Void)? = nil) {
        
        
        
        // if presented as modal
        if presentingViewController?.presentedViewController == self {
            
            dismiss(animated: animateOnDismiss, completion: { [weak self] _ in
                
                self?.dismissCompletionCallback?()
                
                completionHandler?()
            })
            
            return
            
        // if pushed in a navigation controller
        } else if navigationController != nil {
        
            navigationController!.popViewController(animated: animateOnDismiss)
            
        } else if parent?.childViewControllers.contains(self) == true {
            
            
            self.dismissCompletionCallback?()
            
            completionHandler?()
            
            return
        }
        
        dismissCompletionCallback?()
        
        completionHandler?()
    }
    
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        //keep a handle to the completion, you'll need it continue once you get the inputs from the end user
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        //authenticationInput has details about the last known username if you need to use it
    }
    
    public func didCompleteStepWithError(_ error: Error) {
        DispatchQueue.main.async {
            //self.dismissPasscodeLock(lock: self.passcodeLock)
        }
    }
    
    // MARK: - Animations
    
    internal func animateWrongPassword() {
        
        deleteSignButton?.isEnabled = false
        isPlaceholdersAnimationCompleted = false
        
        animatePlaceholders(placeholders: placeholders, toState: .Error)
        
        placeholdersX?.constant = -40
        view.layoutIfNeeded()
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.2,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                
                self.placeholdersX?.constant = 0
                self.view.layoutIfNeeded()
            },
            completion: { completed in
                
                self.isPlaceholdersAnimationCompleted = true
                self.animatePlaceholders(placeholders: self.placeholders, toState: .Inactive)
        })
    }
    
    internal func animatePlaceholders(placeholders: [PasscodeSignPlaceholderView], toState state: PasscodeSignPlaceholderView.State) {
        
        for placeholder in placeholders {
            
            placeholder.animateState(state: state)
        }
    }
    
    private func animatePlacehodlerAtIndex(index: Int, toState state: PasscodeSignPlaceholderView.State) {
        
        guard index < placeholders.count && index >= 0 else { return }
        
        placeholders[index].animateState(state: state)
    }

    // MARK: - PasscodeLockDelegate
    
    public func passcodeLockDidSucceed(lock: PasscodeLockType) {
        
        deleteSignButton?.isEnabled = true
        animatePlaceholders(placeholders: placeholders, toState: .Inactive)
        dismissPasscodeLock(lock: lock) {
            print("Calling success callback")
            self.successCallback?(lock: lock)
        }
    }
    
    public func passcodeLockDidFail(lock: PasscodeLockType, failureType: FailureType, priorAction: ActionAfterConfirmation = .unknown) {
        
        self.animateWrongPassword()
        
        var lock = lock
        
        var tooManyIncorrect = false
        
        if lock.state is EnterPasscodeState {
            print("Registering incorrect passcode.")
            tooManyIncorrect = lock.state.registerIncorrectPasscode(lock: lock)
        }
        
        
        if !tooManyIncorrect {
            if failureType == .emailTaken {
                
                emailTakenAlert(lock: lock)
                
            }
            else if failureType == .notConfirmed {
                notConfirmedAlert(lock: lock, priorAction: priorAction)
            }
            else if failureType == .invalidEmail {
                invalidEmailAlert(lock: lock)
            }
            else if failureType == .incorrectPasscode {
                incorrectPasscodeAlert(lock: lock)
            }
            else {
                animateWrongPassword()
            }
        }
    }
    
    public func passcodeLockDidChangeState(lock: PasscodeLockType) {
        
        updatePasscodeView()
        animatePlaceholders(placeholders: placeholders, toState: .Inactive)
        deleteSignButton?.isEnabled = false
    }
    
    public func passcodeLock(lock: PasscodeLockType, addedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index: index, toState: .Active)
        deleteSignButton?.isEnabled = true
    }
    
    public func passcodeLock(lock: PasscodeLockType, removedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index: index, toState: .Inactive)
        
        if index == 0 {
            
            deleteSignButton?.isEnabled = false
        }
    }
    
    // MARK: - SCLAlertViews
    
    func emailTakenAlert(lock: PasscodeLockType) {
        let alert = SCLAlertView()
        
        let txt = alert.addTextField("Enter a new email")
        txt.autocapitalizationType = .none
        txt.tag = 0
        txt.delegate = self
        
        let newEmailButton = alert.addButton("Try Again With New Email") {
            Pool.sharedInstance.setEmail(email: txt.text!)
            self.switchToSetPasscodeState(lock: lock)
        }
        
        newEmailButton.tag = 1
        
        newEmailButton.isEnabled = false
        newEmailButton.alpha = 0.5
        
        _ = alert.addButton("Forgot Password") {
            print("Attempting to change a forgotten passcode.")
            
            Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                
                if task.error?._code == 7 {
                    print("User must be confirmed to claim a forgotten password. Sort of ridiculous, but whatever.")
                    self.passcodeLockDidFail(lock: lock, failureType: .notConfirmed, priorAction: .resetPassword)
                }
                else {
                    self.passcodeLockDidFail(lock: lock, failureType: .unknown)
                }
                
            }.onForgottenPasswordSuccess {task in
                self.switchToAWSCodeState(lock: lock, codeType: .forgottenPassword, priorAction: .unknown)
            }
        }
        
        _ = alert.showInfo("Email is Already Taken", subTitle: "Please input a new email or request a password reset.", closeButtonTitle: "Go Back", duration: 0)
    }
    
    func notConfirmedAlert(lock: PasscodeLockType, priorAction: ActionAfterConfirmation) {
        let alert = SCLAlertView()
        
        _ = alert.addButton("Confirm Email") {
            Pool.sharedInstance.user?.getAttributeVerificationCode("email")
            
            self.switchToAWSCodeState(lock: lock, codeType: .attributeVerification, priorAction: priorAction)
        }
        
        _ = alert.showNotice("Email Uncomfirmed", subTitle: "Please continue to email confirmation before attempting that task again.", closeButtonTitle: "Go Back", duration: 0)
    }
    
    func invalidEmailAlert(lock: PasscodeLockType) {
        let appearance = SCLAlertView.SCLAppearance(showCloseButton: false)
        
        let alert = SCLAlertView(appearance: appearance)
        
        
        _ = alert.addButton("Sign Up Using That Email") {
            self.switchToSetPasscodeState(lock: lock)
        }
        
        _ = alert.addButton("Choose a Different Email") {
            self.dismissPasscodeLock(lock: lock)
        }
        
        _ = alert.showInfo("Invalid Email", subTitle: "Your email is not signed up.", duration: 0)
    }
    
    func incorrectPasscodeAlert(lock: PasscodeLockType) {
        
        let alert = SCLAlertView()
        
        _ = alert.addButton("Choose a New Passcode") {
            print("Attempting to change a forgotten passcode.")
            
            Pool.sharedInstance.forgotPassword().onForgottenPasswordFailure {task in
                
                if task.error?._code == 7 {
                    print("User must be confirmed to claim a forgotten password. Sort of ridiculous, but whatever.")
                    
                    self.passcodeLockDidFail(lock: lock, failureType: .notConfirmed, priorAction: .resetPassword)
                }
                else {
                    self.passcodeLockDidFail(lock: lock, failureType: .unknown)
                }
                
            }.onForgottenPasswordSuccess {task in
                    self.switchToAWSCodeState(lock: lock, codeType: .forgottenPassword, priorAction: .logIn)
            }
        }
        
        _ = alert.addButton("Choose a Different Email") {
            self.dismissPasscodeLock(lock: lock)
        }
        
        _ = alert.showInfo("Incorrect Passcode", subTitle: "Your passcode did not match the one on record.", closeButtonTitle: "Try Again", duration: 0)
    }
    
    // MARK: - State Changing Methods
    
    func switchToAWSCodeState(lock: PasscodeLockType, codeType: AWSCodeType, priorAction: ActionAfterConfirmation) {
        DispatchQueue.main.async {
            let nextState = AWSCodeState(codeType: codeType, priorAction: priorAction)
            lock.changeStateTo(state: nextState)
        }
    }
    
    func switchToChangePasscodeState(lock: PasscodeLockType) {
        DispatchQueue.main.async {
            let nextState = ChangePasscodeState()
            lock.changeStateTo(state: nextState)
        }
    }
    
    func switchToSetPasscodeState(lock: PasscodeLockType) {
        DispatchQueue.main.async {
            let nextState = SetPasscodeState()
            lock.changeStateTo(state: nextState)
        }
    }
    
    // MARK: - AWS Protocol Methods
    
    public func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        return self
    }
    
    public func startMultiFactorAuthentication() -> AWSCognitoIdentityMultiFactorAuthentication {
        return self
    }
    
    public func getCode(_ authenticationInput: AWSCognitoIdentityMultifactorAuthenticationInput, mfaCodeCompletionSource: AWSTaskCompletionSource<NSString>) {
        
    }
    
    public func didCompleteMultifactorAuthenticationStepWithError(_ error: Error) {
        
    }
}

// We need this extension to manipulate buttons and text fields in alert views.

extension PasscodeLockViewController: UITextFieldDelegate {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        print("TextField did begin editing method called")
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        print("TextField did end editing method called")
    }
    
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        print("TextField should begin editing method called")
        return true
    }
    
    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        print("TextField should clear method called")
        return true
    }
    
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        print("TextField should snd editing method called")
        return true
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("While entering the characters this method gets called")
        
        if textField.tag == 0 {
            if textField.text!.isEmail == true {
                if let button = textField.superview?.viewWithTag(1) as? UIButton {
                    button.isEnabled = true
                    button.alpha = 1
                }
            }
            else {
                if let button = textField.superview?.viewWithTag(1) as? UIButton {
                    button.isEnabled = false
                    button.alpha = 0.5
                }
            }
        }
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("TextField should return method called")
        textField.resignFirstResponder();
        return true
    }
}
