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

public class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate, AWSCognitoIdentityInteractiveAuthenticationDelegate, AWSCognitoIdentityPasswordAuthentication, AWSCognitoIdentityMultiFactorAuthentication {
    
    public var page = 0
    
    public enum LockState {
        case EnterPasscode(email: String?)
        case SetPasscode(email: String?)
        case ChangePasscode(email: String?)
        case RemovePasscode
        case AWSCode(email: String?, codeType: AWSCodeType)
        
        func getState() -> PasscodeLockStateType {
            
            switch self {
                case .EnterPasscode(let email): return EnterPasscodeState(userEmail: email)
                case .SetPasscode(let email): return SetPasscodeState(userEmail: email)
                case .ChangePasscode(let email): return ChangePasscodeState(userEmail: email)
                case .RemovePasscode: return EnterPasscodeState(allowCancellation: true)
                case .AWSCode(let email, let codeType): return AWSCodeState(userEmail: email, codeType: codeType)
            }
        }
    }
    
    @IBOutlet public weak var titleLabel: UILabel?
    @IBOutlet public weak var descriptionLabel: UILabel?
    @IBOutlet public var placeholders: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
    @IBOutlet public weak var cancelButton: UIButton?
    @IBOutlet public weak var deleteSignButton: UIButton?
    @IBOutlet public weak var touchIDButton: UIButton?
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
        
        Pool.sharedInstance.userPool().delegate = self
        Pool.sharedInstance.user = Pool.sharedInstance.userPool().getUser(passedEmail!)
        
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
        
        // Causes a crash
        notificationCenter?.addObserver(self, selector: #selector(self.appWillEnterForegroundHandler(notification:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        // Doesn't cause a crash
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
    
    public func didCompleteStepWithError(_ error: NSError) {
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
        dismissPasscodeLock(lock: lock, completionHandler: { [weak self] _ in
            self?.successCallback?(lock: lock)
        })
    }
    
    public func passcodeLockDidFail(lock: PasscodeLockType, failureType: FailureType) {
        
        if failureType == .emailTaken {
            
            emailTakenAlert(lock: lock)
            
        }
        else if failureType == .notConfirmed {
            notConfirmedAlert(lock: lock)
        }
        else if failureType == .wrongCredentials {
            
        }
        else {
            animateWrongPassword()
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
        
        _ = alert.addButton("Try Again With New Email") {
            print("Changing state")
            self.switchToSetPasscodeState(lock: lock, email: txt.text!)
        }
        
        _ = alert.addButton("Forgot Password") {
            print("Attempting to change a forgotten passcode.")
            
            Pool.sharedInstance.forgotPassword(userEmail: lock.state.getEmail()!).onForgottenPasswordFailure {task in
                
                if task.error?.code == 7 {
                    print("User must be confirmed to claim a forgotten password. Sort of ridiculous, but whatever.")
                    self.passcodeLockDidFail(lock: lock, failureType: .notConfirmed)
                }
                else {
                    self.passcodeLockDidFail(lock: lock, failureType: .unknown)
                }
                
            }.onForgottenPasswordSuccess {task in
                self.switchToAWSCodeState(lock: lock, codeType: .forgottenPassword)
            }
        }
        
        _ = alert.showInfo("Email is Already Taken", subTitle: "Please input a new email or request a password reset.", closeButtonTitle: "Go Back", duration: 0)
    }
    
    func notConfirmedAlert(lock: PasscodeLockType) {
        let alert = SCLAlertView()
        
        _ = alert.addButton("Confirm Email") {
            self.switchToAWSCodeState(lock: lock, codeType: .confirmation)
        }
        
        _ = alert.showNotice("Email Uncomfirmed", subTitle: "Please continue to email confirmation before attempting that task again.", closeButtonTitle: "Go Back", duration: 0)
    }
    
    // MARK: - State Changing Methods
    
    func switchToAWSCodeState(lock: PasscodeLockType, codeType: AWSCodeType) {
        DispatchQueue.main.async {
            let nextState = AWSCodeState(userEmail: lock.state.getEmail(), codeType: codeType)
            lock.changeStateTo(state: nextState)
        }
    }
    
    func switchToChangePasscodeState(lock: PasscodeLockType) {
        DispatchQueue.main.async {
            let nextState = ChangePasscodeState(userEmail: lock.state.getEmail())
            lock.changeStateTo(state: nextState)
        }
    }
    
    func switchToSetPasscodeState(lock: PasscodeLockType, email: String? = nil) {
        DispatchQueue.main.async {
            if email == nil {
                let nextState = SetPasscodeState(userEmail: lock.state.getEmail())
                lock.changeStateTo(state: nextState)
            }
            else {
                let nextState = SetPasscodeState(userEmail: email)
                lock.changeStateTo(state: nextState)
            }
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
    
    public func didCompleteMultifactorAuthenticationStepWithError(_ error: NSError) {
        
    }
}
