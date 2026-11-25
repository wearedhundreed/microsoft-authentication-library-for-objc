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

#import "SampleLoginViewController.h"
#import "SampleAppErrors.h"
#import "SampleAppDelegate.h"
#import "SampleMSALUtil.h"
#import "SampleMainViewController.h"

@interface SampleExternalIDSignedInViewController : SampleBaseViewController

@property (nonatomic, copy) NSString *username;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation SampleExternalIDSignedInViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *heading = [UILabel new];
    heading.text = @"External ID signed in";
    heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    heading.numberOfLines = 0;

    UILabel *account = [UILabel new];
    account.text = self.username;
    account.numberOfLines = 0;

    self.statusLabel = [UILabel new];
    self.statusLabel.numberOfLines = 0;

    UIButton *getToken = [UIButton buttonWithType:UIButtonTypeSystem];
    [getToken setTitle:@"Get token" forState:UIControlStateNormal];
    [getToken addTarget:self action:@selector(getToken:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *signOut = [UIButton buttonWithType:UIButtonTypeSystem];
    [signOut setTitle:@"Sign out" forState:UIControlStateNormal];
    [signOut addTarget:self action:@selector(signOut) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading, account, self.statusLabel, getToken, signOut]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-24],
        [stack.centerYAnchor constraintEqualToAnchor:guide.centerYAnchor],
        [getToken.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [signOut.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
}

- (void)getToken:(UIButton *)button
{
    button.enabled = NO;
    self.statusLabel.text = @"Requesting token…";
    [[SampleMSALUtil sharedUtil] acquireExternalIDTokenWithParentController:self
                                                          completionBlock:^(NSString *token, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            button.enabled = YES;
            self.statusLabel.text = token.length ? @"Token acquired." : @"Token unavailable.";
            if (error)
            {
                [self showDialogForError:error];
            }
        });
    }];
}

- (void)signOut
{
    [[SampleMSALUtil sharedUtil] signOutExternalID];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface SampleLoginViewController ()

@end

@implementation SampleLoginViewController

+ (instancetype)sharedViewController
{
    static SampleLoginViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[SampleLoginViewController alloc] initWithNibName:@"SampleLoginView" bundle:nil];
    });
    
    return s_controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)signIn:(id)sender
{
    [[SampleMSALUtil sharedUtil] signInAccountWithParentController:self
                                                        completion:^(MSALAccount *account, NSString *token, NSError *error)
    {
        if (error)
        {
            // Don't bother showing an error if the user cancels the sign in flow.
            if (!([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorUserCanceled))
            {
                [self showDialogForError:error];
            }
            
            return;
        }
        
        [SampleAppDelegate setCurrentViewController:[SampleMainViewController sharedViewController]];
    }];
}

- (IBAction)signInExternalID:(id)sender
{
    UIButton *button = sender;
    button.enabled = NO;
    [button setTitle:@"Opening sign-in…" forState:UIControlStateDisabled];
    [[SampleMSALUtil sharedUtil] signInExternalIDWithParentController:self
                                                           completion:^(MSALAccount *account, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            button.enabled = YES;
        });
        if (error)
        {
            if (![error.domain isEqualToString:MSALErrorDomain] || error.code != MSALErrorUserCanceled)
            {
                [self showDialogForError:error];
            }
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            SampleExternalIDSignedInViewController *screen = [SampleExternalIDSignedInViewController new];
            screen.username = account.username ?: @"Customer account authenticated.";
            screen.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:screen animated:YES completion:nil];
        });
    }];
}

- (float)startY
{
    return -1.0f;
}

@end
