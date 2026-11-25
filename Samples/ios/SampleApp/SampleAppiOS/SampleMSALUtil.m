//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <MSAL/MSAL.h>
#import <MSAL/MSALLoggerConfig.h>

#import "SampleMSALUtil.h"
#import "SampleExternalIDConfiguration.h"
#import "SampleAppErrors.h"
#import "SampleCalendarUtil.h"
#import "SamplePhotoUtil.h"

#define CURRENT_ACCOUNT_KEY @"MSALCurrentAccountIdentifier"
#define CLIENT_ID @"58391843-2c87-41d1-a457-80b095b7c83f"
#define EXTERNAL_ID_ACCOUNT_KEY @"MSALExternalIDCurrentAccountIdentifier"

static NSString * const SampleExternalIDScopesKey = @"ExternalIDScopes";
static NSString * const SampleExternalIDErrorDomain = @"SampleExternalIDConfigurationErrorDomain";

static NSError *SampleExternalIDConfigurationError(NSString *message)
{
    return [NSError errorWithDomain:SampleExternalIDErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : message}];
}

static NSArray<NSString *> *SampleRegisteredURLSchemes(void)
{
    NSMutableArray<NSString *> *schemes = [NSMutableArray array];
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    for (NSDictionary *urlType in urlTypes)
    {
        for (NSString *scheme in urlType[@"CFBundleURLSchemes"])
        {
            if ([scheme isKindOfClass:NSString.class])
            {
                [schemes addObject:scheme];
            }
        }
    }

    return schemes;
}

@implementation SampleMSALUtil

+ (instancetype)sharedUtil
{
    static SampleMSALUtil *s_sharedUtil = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_sharedUtil = [SampleMSALUtil new];
    });
    
    return s_sharedUtil;
}

+ (void)setup
{
    [MSALGlobalConfig.loggerConfig setLogCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII)
    {
        // If PiiLoggingEnabled is set YES, this block will potentially contain sensitive information (Personally Identifiable Information), but not all messages will contain it.
        // containsPII == YES indicates if a particular message contains PII.
        // You might want to capture PII only in debug builds, or only if you take necessary actions to handle PII properly according to legal requirements of the region
        
        // if message is "redirect to https://somehost.com",
        if (!containsPII)
        {
            // WILL CONTAIN EVERYTHING
            // so message contains "redirect to https://somehost.com"
#if DEBUG
            // NB! This sample uses print just for testing purposes
            // You should only ever log to NSLog in debug mode to prevent leaking potentially sensitive information
            NSLog(@"%@", message);
#endif
        }
        
        else
        {
            // message contains "redirect to unknown host" or "redirect to (non-nil)"
        }
    }];
}

- (MSALPublicClientApplication *)createClientApplication
{
    return [self createClientApplicationWithError:nil];
}

- (MSALPublicClientApplication *)createClientApplicationWithError:(NSError **)error
{
    // This MSALPublicClientApplication object is the representation of your app listing, in MSAL. For your own app
    // go to the Microsoft App Portal to register your own applications with their own client
    // IDs.
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:CLIENT_ID];
    return [[MSALPublicClientApplication alloc] initWithConfiguration:config error:error];
}

- (MSALPublicClientApplication *)createExternalIDApplicationWithError:(NSError **)error
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary<NSString *, id> *configuration = [SampleExternalIDConfiguration validatedConfigurationFromInfoDictionary:bundle.infoDictionary
                                                                                                           bundleIdentifier:bundle.bundleIdentifier
                                                                                                       registeredURLSchemes:SampleRegisteredURLSchemes()
                                                                                                                      error:error];
    if (!configuration)
    {
        return nil;
    }

    NSError *authorityError = nil;
    MSALAuthority *authority = [MSALAuthority authorityWithURL:configuration[@"authorityURL"] error:&authorityError];
    if (!authority)
    {
        if (error)
        {
            *error = authorityError ?: SampleExternalIDConfigurationError(@"MSAL could not create an authority from the configured External ID URL.");
        }
        return nil;
    }

    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:configuration[@"clientId"]
                                                                                                  redirectUri:configuration[@"redirectUri"]
                                                                                                    authority:authority];
    return [[MSALPublicClientApplication alloc] initWithConfiguration:config error:error];
}

+ (BOOL)handleMSALResponse:(NSURL *)url sourceApplication:(NSString * _Nullable)sourceApplication
{
    if (![SampleExternalIDConfiguration isMSALResponseURL:url registeredURLSchemes:SampleRegisteredURLSchemes()])
    {
        return NO;
    }

    return [MSALPublicClientApplication handleMSALResponse:url sourceApplication:sourceApplication];
}

- (void)signInExternalIDWithParentController:(UIViewController *)controller
                                 completion:(void (^)(MSALAccount *account, NSError *error))completion
{
    NSError *configurationError = nil;
    MSALPublicClientApplication *application = [self createExternalIDApplicationWithError:&configurationError];
    if (!application)
    {
        completion(nil, configurationError);
        return;
    }

    NSArray<NSString *> *scopes = [[NSBundle mainBundle] objectForInfoDictionaryKey:SampleExternalIDScopesKey];
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                                      webviewParameters:webParameters];
    [application acquireTokenWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
    {
        if (error)
        {
            completion(nil, error);
            return;
        }

        if (!result.account.identifier)
        {
            completion(nil, SampleExternalIDConfigurationError(@"MSAL did not return an account identifier for the External ID sign-in."));
            return;
        }

        [[NSUserDefaults standardUserDefaults] setObject:result.account.identifier forKey:EXTERNAL_ID_ACCOUNT_KEY];
        completion(result.account, nil);
    }];
}

- (void)signOutExternalID
{
    NSError *configurationError = nil;
    MSALPublicClientApplication *application = [self createExternalIDApplicationWithError:&configurationError];
    NSString *accountIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:EXTERNAL_ID_ACCOUNT_KEY];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:EXTERNAL_ID_ACCOUNT_KEY];
    if (!application || !accountIdentifier)
    {
        return;
    }

    NSError *accountError = nil;
    MSALAccount *account = [application accountForIdentifier:accountIdentifier error:&accountError];
    if (account)
    {
        [application removeAccount:account error:nil];
    }
}

- (void)acquireExternalIDTokenWithParentController:(UIViewController *)controller
                                   completionBlock:(void (^)(NSString *token, NSError *error))completion
{
    NSError *configurationError = nil;
    MSALPublicClientApplication *application = [self createExternalIDApplicationWithError:&configurationError];
    if (!application)
    {
        completion(nil, configurationError);
        return;
    }

    NSString *accountIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:EXTERNAL_ID_ACCOUNT_KEY];
    if (!accountIdentifier)
    {
        completion(nil, SampleExternalIDConfigurationError(@"Sign in with External ID before requesting a token."));
        return;
    }

    NSError *accountError = nil;
    MSALAccount *account = [application accountForIdentifier:accountIdentifier error:&accountError];
    if (!account)
    {
        completion(nil, accountError ?: SampleExternalIDConfigurationError(@"The cached External ID account is no longer available."));
        return;
    }

    NSArray<NSString *> *scopes = [[NSBundle mainBundle] objectForInfoDictionaryKey:SampleExternalIDScopesKey];
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
    {
        if (!error)
        {
            completion(result.accessToken, nil);
            return;
        }

        if (![error.domain isEqualToString:MSALErrorDomain] || error.code != MSALErrorInteractionRequired)
        {
            completion(nil, error);
            return;
        }

        MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
        MSALInteractiveTokenParameters *interactiveParameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                                                    webviewParameters:webParameters];
        interactiveParameters.account = account;
        [application acquireTokenWithParameters:interactiveParameters completionBlock:^(MSALResult *interactiveResult, NSError *interactiveError)
        {
            completion(interactiveResult.accessToken, interactiveError);
        }];
    }];
}

- (NSString *)currentAccountIdentifer
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:CURRENT_ACCOUNT_KEY];
}

- (MSALAccount *)currentAccount:(NSError *__autoreleasing *)error
{
    // We retrieve our current account by checking for the accountIdentifier that we stored in NSUserDefaults when
    // we first signed in the account.
    NSString *currentAccountIdentifer = [self currentAccountIdentifer];
    if (!currentAccountIdentifer)
    {
        // If we did not find an identifier then return nil with a no account signed
        // in error specific for the application.
        if (error)
        {
            *error = [NSError errorWithDomain:SampleAppErrorDomain code:SampleAppNoUserSignedIn userInfo:nil];
        }
        
        return nil;
    }
    
    // Because error is an optional parameter we need to pass in our own error pointer to make sure we get
    // an error back so we can inspect it after.
    NSError *localError = nil;
    
    // Ask MSALPublicClientApplication object to retrieve the account from the cache.
    MSALAccount *account = [[self createClientApplication] accountForIdentifier:currentAccountIdentifer error:&localError];
    
    // If we did not find an account because it wasn't found in the cache then that must mean someone else removed
    // the account underneath us, either due to multiple apps sharing a client ID, or due to the account restoring an
    // image from another device. In this case it is best to detect that case and clean up local state.
    if (!account && !localError)
    {
        [self cleanupLocalState];
    }
    
    // NSError ** is traditionally an optional parameters, so we should check to make sure it is not nil before
    // filling it.
    if (error)
    {
        *error = localError;
    }
    
    return account;
}

- (void)signInAccountWithParentController:(UIViewController *)controller
                               completion:(void (^)(MSALAccount *account, NSString *token, NSError *error))signInBlock
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createClientApplicationWithError:&error];
    if (!application)
    {
        signInBlock(nil, nil, error);
        return;
    }
    
    // When signing in an account for the first time we acquire a token without providing
    // an account object. If you've previously asked the user for an email address,
    // or phone number you can provide that as a "login hint."
    
    // Request as many scopes as possible up front that you know your application will
    // want to use so the service can request consent for them up front and minimize
    // how much users are interrupted for interactive auth.
    
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"User.Read", @"Calendars.Read"] webviewParameters:webParameters];
    [application acquireTokenWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
    {
        if (error)
        {
            signInBlock(nil, nil, error);
            return;
        }
        
        // In the initial acquire token call we'll want to look at the account object
        // that comes back in the result.
        MSALAccount *account = result.account;
        
        // The identifier in the MSALAccount is the key to retrieve this account from
        // the cache in the future. Save this piece of information in a place you can
        // easily retrieve in your app. In this case we're going to store it in
        // NSUserDefaults.
        [[NSUserDefaults standardUserDefaults] setValue:account.homeAccountId.identifier forKey:CURRENT_ACCOUNT_KEY];
        
        signInBlock(account, result.accessToken, error);
    }];
}

- (void)acquireTokenSilentForCurrentAccount:(NSArray<NSString *> *)scopes
                            completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALAccount *currentAccount = [self currentAccount:&error];
    if (!currentAccount)
    {
        acquireTokenBlock(nil, error);
        return;
    }

    // Depending on how this account has been used with this application before it is possible for there to be multiple
    // tokens of varying authorities for this account in the cache. Because we are trying to get a token specifically
    // for graph in this sample, we would like to get an access token for the account's home authority.
    // acquireTokenSilent call without any authority will use account's home authority by default.
    
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:currentAccount];
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
    {
        acquireTokenBlock(result.accessToken, error);
    }];
}

- (void)acquireTokenInteractiveForCurrentAccount:(NSArray<NSString *> *)scopes
                                parentController:(UIViewController *)controller
                                 completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    MSALPublicClientApplication *application = [self createClientApplication];
    
    NSError *error = nil;
    MSALAccount *currentAccount = [self currentAccount:&error];
    if (!currentAccount)
    {
        acquireTokenBlock(nil, error);
        return;
    }
    
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes webviewParameters:webParameters];
    parameters.account = currentAccount;
    parameters.promptType = MSALPromptTypeDefault;
    
    [application acquireTokenWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
     {
         acquireTokenBlock(result.accessToken, error);
     }];
}

- (void)acquireTokenForCurrentAccount:(NSArray<NSString *> *)scopes
                     parentController:(UIViewController *)controller
                      completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock
{
    [self acquireTokenSilentForCurrentAccount:scopes
                              completionBlock:^(NSString *token, NSError *error)
     {
         if (!error)
         {
             acquireTokenBlock(token, nil);
             return;
         }
         
         // What an app does on an InteractionRequired error will vary from app to app. Most apps
         // will want to present a notification to the account in an unobtrusive way (such as on a
         // status bar in the application UI) before bringing up the modal interactive login dialog,
         // otherwise it can appear to be out of context for the account, and confuse them as to why
         // they are seeing an authentication prompt.
         if ([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorInteractionRequired)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self acquireTokenInteractiveForCurrentAccount:scopes
                                               parentController:controller
                                                completionBlock:acquireTokenBlock];
             });
             return;
         }
         
         acquireTokenBlock(nil, error);
     }];
}

- (void)signOut

{
    MSALPublicClientApplication *application = [self createClientApplication];
    MSALAccount *currentAccount = [self currentAccount:nil];
    [self cleanupLocalState];
    
    // Signing out an account requires removing this from MSAL and cleaning up any extra state that the application
    // might be maintaining outside of MSAL for the account.
    
    // This remove call only removes the account's tokens for this client ID in the local keychain cache. It does
    // not sign the account completely out of the device or remove tokens for the account for other client IDs. If
    // you have multiple applications sharing a client ID this will make the account effectively "disappear" for
    // those applications as well if you are using Keychain Cache Sharing (not currently available in MSAL
    // build preview). We do not recommend sharing a ClientID among multiple apps.
    [application removeAccount:currentAccount error:nil];
    
}

- (void)cleanupLocalState
{
    [[SamplePhotoUtil sharedUtil] clearPhotoCache];
    [[SampleCalendarUtil sharedUtil] clearCache];
    
    // Leave around the account identifier as the last piece of state to clean up as you will probably need
    // it to clean up user-specific state
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CURRENT_ACCOUNT_KEY];
}

@end
