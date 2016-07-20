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

public class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate, AWSCognitoIdentityPasswordAuthentication, AWSCognitoIdentityMultiFactorAuthentication {
    
    public var page = 0
    
    public enum LockState {
        case EnterPasscode
        case SetPasscode
        case ChangePasscode
        case RemovePasscode
        case AWSConfirmation(email: String)
        
        func getState() -> PasscodeLockStateType {
            
            switch self {
                case .EnterPasscode: return EnterPasscodeState()
                case .SetPasscode: return SetPasscodeState()
                case .ChangePasscode: return ChangePasscodeState()
                case .RemovePasscode: return EnterPasscodeState(allowCancellation: true)
                case .AWSConfirmation(let email): return AWSConfirmationState(userEmail: email)
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
    
    internal let passcodeConfiguration: PasscodeLockConfigurationType
    internal let passcodeLock: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted = true
    internal var isConfirmation = false
    
    private var shouldTryToAuthenticateWithBiometrics = true
    
    private var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    private var passedEmail: String?
    
    // MARK: - Initializers
    
    public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, email: String?, animateOnDismiss: Bool = true) {
        
        self.animateOnDismiss = animateOnDismiss
        
        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        
        let nibName = "PasscodeLockView"
        let bundle: Bundle = bundleForResource(name: nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundle)
        
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
        
        self.passedEmail = email
    }
    
    public convenience init(state: LockState, configuration: PasscodeLockConfigurationType, email: String?, animateOnDismiss: Bool = true) {
        
        self.init(state: state.getState(), configuration: configuration, email: email, animateOnDismiss: animateOnDismiss)
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
            
            dismiss(animated: animateOnDismiss, completion: { [weak self] _ in
                
                self?.dismissCompletionCallback?()
                
                completionHandler?()
            })
            
            return
        }
        
        dismissCompletionCallback?()
        
        completionHandler?()
    }
    
    func createAWSUser(userEmail: String, userPassword: String) {
        // AWS Send Email
        
        //setup service config
        if passedEmail != nil {
            let serviceConfiguration = AWSServiceConfiguration(region: .usEast1, credentialsProvider: nil)
            let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: "7r9126v4vlsopi2eovtvqumfc7", clientSecret: "1jfbad1tia2vuvt9v583p4a3h4tbi3u22v2hle06sg0p97682mbd", poolId: "us-east-1_y5cEV6M8J")
            AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
            let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
            _ = AWSCognitoCredentialsProvider(regionType: .usEast1, identityPoolId: "us-east-1_y5cEV6M8J", identityProviderManager:pool)
            
            let email = AWSCognitoIdentityUserAttributeType()
            email?.name = "email"
            email?.value = userEmail
            
            pool.signUp(email!.value!, password: userPassword, userAttributes: [email!], validationData: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
                
                if task.error != nil {
                    print("Some Error")
                    print(task.error!)
                } else {
                    print(task.result)
                    
                    print("Password: \(userPassword)")
                }
                return nil
            })
        }
    }
    
    func logInAWSUser(userEmail: String, userPassword: String) {
        if passedEmail != nil {
            let serviceConfiguration = AWSServiceConfiguration(region: .usEast1, credentialsProvider: nil)
            let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: "7r9126v4vlsopi2eovtvqumfc7", clientSecret: "1jfbad1tia2vuvt9v583p4a3h4tbi3u22v2hle06sg0p97682mbd", poolId: "us-east-1_y5cEV6M8J")
            AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
            let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
            _ = AWSCognitoCredentialsProvider(regionType: .usEast1, identityPoolId: "us-east-1_y5cEV6M8J", identityProviderManager:pool)
            
            let user = pool.getUser(userEmail)
            
            user.getSession(userEmail, password: userPassword, validationData: nil, scopes: nil).continue(with: AWSExecutor.mainThread(), with: {(task: AWSTask!) -> AnyObject! in
                
                if task.error != nil {
                    print(task.error!)
                    
                    print("Not Authenticated.")
                    
                    user.resendConfirmationCode()
                    
                    DispatchQueue.main.async {
                        self.titleLabel?.text = "Account Not Confirmed"
                        self.descriptionLabel?.text = "Enter the code found in your email to proceed"
                        
                        self.passcodeLock.changeStateTo(state: AWSConfirmationState(userEmail: userEmail))
                    }
                    
                }
                else {
                    print(task.result)
                }
                
                return nil
            })
        }
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
    
    public func getCode(_ authenticationInput: AWSCognitoIdentityMultifactorAuthenticationInput, mfaCodeCompletionSource: AWSTaskCompletionSource<NSString>) {
        
    }
    
    public func didCompleteMultifactorAuthenticationStepWithError(_ error: NSError) {
        
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
        
        if lock.state is ConfirmPasscodeState {
            createAWSUser(userEmail: passedEmail!, userPassword: lock.repository.getPasscode())
        }
        else if lock.state is EnterPasscodeState {
            logInAWSUser(userEmail: passedEmail!, userPassword: lock.repository.getPasscode())
        }
        print("Lock State: \(lock.state)")
        
        deleteSignButton?.isEnabled = true
        animatePlaceholders(placeholders: placeholders, toState: .Inactive)
        dismissPasscodeLock(lock: lock, completionHandler: { [weak self] _ in
            self?.successCallback?(lock: lock)
        })
    }
    
    public func passcodeLockDidFail(lock: PasscodeLockType) {
        
        animateWrongPassword()
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
}
