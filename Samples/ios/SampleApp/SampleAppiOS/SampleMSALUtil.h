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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class MSALAccount;

@interface SampleMSALUtil : NSObject

+ (instancetype)sharedUtil;

/*!
    Called during app intialization to set up app-wide MSAL properties.
 */
+ (void)setup;


- (NSString *)currentAccountIdentifer;

/*!
    Returns the current account for the application
 */
- (MSALAccount *)currentAccount:(NSError * __autoreleasing *)error;

/*!
    Signs in an account using MSAL.
 */
- (void)signInAccountWithParentController:(UIViewController *)controller
                               completion:(void (^)(MSALAccount *account, NSString *token, NSError *error))signInBlock;

/*!
    Removes MSAL account state from the application.
 */

- (void)signOut;

/*!
    Acquires a token to use against graph for the current account
 */
- (void)acquireTokenForCurrentAccount:(NSArray<NSString *> *)scopes
                     parentController:(UIViewController *)controller
                      completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

/*!
    Acquires a token using an interactive flow for the current account. Used if
    the library returns MSALErrorInteractionRequired.
 */
- (void)acquireTokenInteractiveForCurrentAccount:(NSArray<NSString *> *)scopes
                                parentController:(UIViewController *)controller
                                 completionBlock:(void (^)(NSString *token, NSError *error))acquireTokenBlock;

/*! Starts browser based External ID sign-in using its own client configuration and account state. */
- (void)signInExternalIDWithParentController:(UIViewController *)controller
                                 completion:(void (^)(MSALAccount *account, NSError *error))completion;

/*! Removes the External ID account from this app's MSAL token cache. */
- (void)signOutExternalID;

/*! Acquires External ID scopes silently and falls back only when MSAL requires interaction. */
- (void)acquireExternalIDTokenWithParentController:(UIViewController *)controller
                                   completionBlock:(void (^)(NSString *token, NSError *error))completion;

/*! Routes only URLs matching a URL scheme registered by this app to MSAL. */
+ (BOOL)handleMSALResponse:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication;

@end
