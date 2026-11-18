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

#import "SampleExternalIDConfiguration.h"

static NSString * const SampleExternalIDConfigurationErrorDomain = @"SampleExternalIDConfigurationErrorDomain";
static NSString * const SampleExternalIDClientIdKey = @"ExternalIDClientId";
static NSString * const SampleExternalIDAuthorityKey = @"ExternalIDAuthority";
static NSString * const SampleExternalIDRedirectUriKey = @"ExternalIDRedirectUri";
static NSString * const SampleExternalIDScopesKey = @"ExternalIDScopes";

@implementation SampleExternalIDConfiguration

+ (nullable NSDictionary<NSString *, id> *)validatedConfigurationFromInfoDictionary:(NSDictionary<NSString *, id> *)infoDictionary
                                                                      bundleIdentifier:(nullable NSString *)bundleIdentifier
                                                                  registeredURLSchemes:(NSArray<NSString *> *)registeredURLSchemes
                                                                                 error:(NSError * _Nullable * _Nullable)error
{
    NSString *clientId = infoDictionary[SampleExternalIDClientIdKey];
    NSString *authorityString = infoDictionary[SampleExternalIDAuthorityKey];
    NSString *redirectUri = infoDictionary[SampleExternalIDRedirectUriKey];
    NSArray<NSString *> *scopes = infoDictionary[SampleExternalIDScopesKey];
    NSURL *authorityURL = [NSURL URLWithString:authorityString];

    if (![redirectUri isKindOfClass:NSString.class] || redirectUri.length == 0)
    {
        if (bundleIdentifier.length > 0)
        {
            redirectUri = [NSString stringWithFormat:@"msauth.%@://auth", bundleIdentifier];
        }
    }

    NSURL *redirectURL = [NSURL URLWithString:redirectUri];
    BOOL validClientId = [clientId isKindOfClass:NSString.class] &&
        [[NSUUID alloc] initWithUUIDString:clientId] != nil;
    BOOL validAuthority = authorityURL &&
        [authorityURL.scheme.lowercaseString isEqualToString:@"https"] &&
        [authorityURL.host.lowercaseString hasSuffix:@".ciamlogin.com"] &&
        ![authorityURL.host.uppercaseString containsString:@"TENANT_SUBDOMAIN"] &&
        ![authorityURL.host containsString:@"<"];
    BOOL validRedirect = redirectURL &&
        [redirectURL.scheme.lowercaseString isEqualToString:@"msauth"] &&
        redirectURL.host.length > 0 &&
        (redirectURL.path.length == 0 || [redirectURL.path.lowercaseString isEqualToString:@"/auth"]) &&
        [self isMSALResponseURL:redirectURL registeredURLSchemes:registeredURLSchemes];
    BOOL validScopes = [scopes isKindOfClass:NSArray.class] && scopes.count > 0;
    if ([scopes isKindOfClass:NSArray.class])
    {
        for (id scope in scopes)
        {
            if (![scope isKindOfClass:NSString.class] || [scope stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0)
            {
                validScopes = NO;
                break;
            }
        }
    }

    if (!validClientId || !validAuthority || !validRedirect || !validScopes)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:SampleExternalIDConfigurationErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey : @"Configure a valid External ID client ID, ciamlogin.com authority, registered MSAL redirect URI, and nonempty delegated scopes."}];
        }
        return nil;
    }

    return @{@"clientId" : clientId,
             @"authorityURL" : authorityURL,
             @"redirectUri" : redirectUri,
             @"scopes" : scopes};
}

+ (BOOL)isMSALResponseURL:(NSURL *)url registeredURLSchemes:(NSArray<NSString *> *)registeredURLSchemes
{
    if (!url.scheme.length || ![url.host.lowercaseString isEqualToString:@"auth"])
    {
        return NO;
    }

    for (NSString *scheme in registeredURLSchemes)
    {
        if ([scheme caseInsensitiveCompare:url.scheme] == NSOrderedSame)
        {
            return YES;
        }
    }

    return NO;
}

@end
