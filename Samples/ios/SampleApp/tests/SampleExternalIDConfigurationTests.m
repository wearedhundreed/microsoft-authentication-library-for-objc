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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>

#import "../SampleAppiOS/SampleExternalIDConfiguration.h"

@interface SampleExternalIDConfigurationTests : XCTestCase
@end

@implementation SampleExternalIDConfigurationTests

- (NSDictionary<NSString *, id> *)validConfiguration
{
    return @{@"ExternalIDClientId" : @"00000000-0000-0000-0000-000000000001",
             @"ExternalIDAuthority" : @"https://contoso.ciamlogin.com/",
             @"ExternalIDScopes" : @[@"api://contoso/sample.read"]};
}

- (void)testConfigurationRequiresTenantValuesAndScopes
{
    NSDictionary *placeholders = @{@"ExternalIDClientId" : @"REPLACE_WITH_EXTERNAL_ID_APPLICATION_CLIENT_ID",
                                  @"ExternalIDAuthority" : @"https://<TENANT_SUBDOMAIN>.ciamlogin.com/",
                                  @"ExternalIDScopes" : @[]};
    NSError *error = nil;

    NSDictionary *configuration = [SampleExternalIDConfiguration validatedConfigurationFromInfoDictionary:placeholders
                                                                                          bundleIdentifier:@"com.example.app"
                                                                                      registeredURLSchemes:@[@"msauth.com.example.app"]
                                                                                                     error:&error];

    XCTAssertNil(configuration);
    XCTAssertNotNil(error);
}

- (void)testConfigurationDerivesRedirectFromBundleIdentifier
{
    NSError *error = nil;
    NSDictionary *configuration = [SampleExternalIDConfiguration validatedConfigurationFromInfoDictionary:[self validConfiguration]
                                                                                          bundleIdentifier:@"com.example.app"
                                                                                      registeredURLSchemes:@[@"msauth.com.example.app"]
                                                                                                     error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(configuration[@"redirectUri"], @"msauth.com.example.app://auth");
    XCTAssertEqualObjects(configuration[@"clientId"], @"00000000-0000-0000-0000-000000000001");
}

- (void)testConfigurationRejectsUnregisteredRedirectScheme
{
    NSError *error = nil;
    NSDictionary *configuration = [SampleExternalIDConfiguration validatedConfigurationFromInfoDictionary:[self validConfiguration]
                                                                                          bundleIdentifier:@"com.example.app"
                                                                                      registeredURLSchemes:@[@"unrelated-scheme"]
                                                                                                     error:&error];

    XCTAssertNil(configuration);
    XCTAssertNotNil(error);
}

- (void)testConfigurationRejectsNonHTTPSAuthority
{
    NSMutableDictionary *configuration = [[self validConfiguration] mutableCopy];
    configuration[@"ExternalIDAuthority"] = @"http://contoso.ciamlogin.com/";
    NSError *error = nil;

    NSDictionary *validatedConfiguration = [SampleExternalIDConfiguration validatedConfigurationFromInfoDictionary:configuration
                                                                                                    bundleIdentifier:@"com.example.app"
                                                                                                registeredURLSchemes:@[@"msauth.com.example.app"]
                                                                                                               error:&error];

    XCTAssertNil(validatedConfiguration);
    XCTAssertNotNil(error);
}

- (void)testCallbackRouterOnlyAcceptsRegisteredAuthRedirect
{
    NSArray *schemes = @[@"msauth.com.example.app"];

    XCTAssertTrue([SampleExternalIDConfiguration isMSALResponseURL:[NSURL URLWithString:@"msauth.com.example.app://auth?code=opaque"]
                                              registeredURLSchemes:schemes]);
    XCTAssertFalse([SampleExternalIDConfiguration isMSALResponseURL:[NSURL URLWithString:@"other://auth?code=opaque"]
                                               registeredURLSchemes:schemes]);
    XCTAssertFalse([SampleExternalIDConfiguration isMSALResponseURL:[NSURL URLWithString:@"msauth.com.example.app://other"]
                                               registeredURLSchemes:schemes]);
}

@end
