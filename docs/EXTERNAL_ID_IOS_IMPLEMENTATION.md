# Microsoft Entra External ID on iOS with MSAL

This guide describes how to integrate this MSAL for iOS/macOS fork with a **Microsoft Entra External ID customer tenant**. It is an application-integration guide; it does not change MSAL's OAuth protocol implementation or add a new authentication protocol to the SDK.

## 1. Choose the authentication experience

External ID supports two distinct mobile patterns:

- **Browser-delegated authentication (MSAL):** use MSAL's public-client APIs and the system browser/broker flow. This is the recommended starting point when the app should use the standard Microsoft identity platform sign-in experience.
- **Native authentication:** use the MSAL `native-auth` capability only when the External ID customer tenant is configured for native authentication and the app needs a fully customizable in-app sign-up/sign-in journey. Native authentication has its own API and tenant prerequisites; it is not enabled merely by changing an authority URL.

Do not combine the two flows in one request. Select the flow based on the tenant configuration and UX requirements.

## 2. Register the iOS application in the External ID tenant

In the Microsoft Entra admin center:

1. Open the **External Identities** customer tenant (not the workforce tenant).
2. Register an application under **App registrations**.
3. Select the iOS/macOS platform and enter the app's actual bundle identifier.
4. Record the **Application (client) ID** and **Directory (tenant) ID**.
5. Configure the redirect URI shown by the iOS platform registration. Use the exact value generated for the app; do not substitute a workforce-tenant redirect URI.
6. Configure the required customer user flows and identity providers in the External ID tenant.
7. For native authentication, additionally enable/configure the tenant's native authentication feature and its supported user flows before using the native-auth APIs.

External ID tenant-specific values are intentionally placeholders in this repository. Never commit a real client secret, access token, refresh token, certificate private key, or other credential. A native iOS public client must not contain a client secret.

## 3. Browser-delegated MSAL configuration

Use the tenant-specific authority supplied for the External ID customer tenant. For an External ID customer tenant, use the authority host `https://<tenant-subdomain>.ciamlogin.com/`. Microsoft documents this tenant-name host as the authority format for external tenants. The tenant-specific OpenID Connect metadata endpoint is published below the tenant ID path; do not append that metadata path to the MSAL authority unless the generated platform quickstart explicitly instructs you to. Copy the exact authority from the tenant's app registration/quickstart; do not guess the tenant subdomain.

Objective-C configuration outline:

```objective-c
#import <MSAL/MSAL.h>

NSString *clientId = @"<EXTERNAL_ID_APPLICATION_CLIENT_ID>";
NSString *authorityURL = @"https://<TENANT_SUBDOMAIN>.ciamlogin.com/";

NSError *configurationError = nil;
MSALAuthority *authority =
    [MSALAuthority authorityWithURL:[NSURL URLWithString:authorityURL]
                              error:&configurationError];

if (configurationError || !authority) {
    // Surface a configuration error. Do not continue with a nil authority.
    return;
}

MSALPublicClientApplicationConfig *config =
    [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId];
config.authority = authority;

NSError *applicationError = nil;
MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                         error:&applicationError];

if (applicationError || !application) {
    // Log only non-sensitive diagnostics; never log tokens or credentials.
    return;
}
```

The authority string above is a template, not a deployable tenant value. Confirm it against the External ID tenant's generated quickstart before shipping. The tenant's OpenID Connect discovery document can be inspected at `https://<TENANT_SUBDOMAIN>.ciamlogin.com/<TENANT_ID>/v2.0/.well-known/openid-configuration` to verify issuer and endpoints.

## 4. Interactive sign-in and token acquisition

Use the registered redirect URI and MSAL's supported interactive token API. Let MSAL generate and validate the OAuth state, nonce, and PKCE values. Do not implement a second authorization-code exchange in application code when MSAL is already managing the flow.

```objective-c
NSArray<NSString *> *scopes = @[@"<API_SCOPE_CONFIGURED_FOR_THIS_APP>"];

MSALWebviewParameters *webParameters =
    [[MSALWebviewParameters alloc]
        initWithAuthPresentationViewController:presentingViewController];

MSALInteractiveTokenParameters *parameters =
    [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                         webviewParameters:webParameters];

[application acquireTokenWithParameters:parameters
                        completionBlock:^(MSALResult *result, NSError *error) {
    if (error) {
        // Handle cancellation and MSAL errors without exposing sensitive data.
        return;
    }

    // Use the access token only for the resource/audience represented by scopes.
    // Store account identifiers as needed; never write tokens to logs.
    NSString *accountIdentifier = result.account.identifier;
    (void)accountIdentifier;
}];
```

The scope must be defined for the target API. Do not request Microsoft Graph scopes unless the application actually calls Microsoft Graph and the tenant grants those permissions.

## 5. Redirect handling

For an iOS application delegate, forward the callback URL to MSAL using the API supported by this SDK version:

```objective-c
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
    return [MSALPublicClientApplication
        handleMSALResponse:url
        sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
}
```

If the app uses scenes or a different lifecycle, route the URL from the corresponding scene callback to MSAL. Ensure the registered redirect URI, URL scheme, and app configuration match exactly. Do not consume MSAL callback URLs as application password-reset or device-pairing codes.

## 6. Silent token acquisition and account lifecycle

After successful interactive sign-in, retain the MSAL account identifier and use MSAL's account lookup and silent-token APIs for subsequent access. If silent acquisition requires interaction, handle the interaction-required result by starting an interactive request. Use MSAL's sign-out API to remove the selected account from the app's MSAL cache.

A successful local sign-out does not necessarily terminate every upstream browser or identity-provider session. Explain that distinction in the product UX where relevant.

## 7. Passkeys, biometrics, and device authorization boundaries

- Passkey/WebAuthn authentication is performed by the identity provider or the relying-party application using platform authentication APIs; MSAL token acquisition is not itself a passkey API.
- Face ID/Touch ID can gate access to app-local sensitive operations, but must not be represented as proof that the External ID user authenticated unless the identity provider issued a corresponding authentication result.
- A headless device should use an appropriate standards-based authorization flow supported by its identity platform configuration. Do not embed a user password, client secret, or private key in a device.
- Device authorization (RFC 8628) must be implemented only where the selected tenant, client type, and MSAL/API surface explicitly support it. Do not assume the iOS interactive API shown above is a device-code API.

## 8. Security and release checklist

- [ ] Use the External ID customer tenant's client ID, tenant ID, authority, and redirect URI.
- [ ] Confirm the exact authority and redirect URI from the generated tenant quickstart.
- [ ] Use Authorization Code with PKCE through MSAL; do not hand-roll PKCE or token exchange.
- [ ] Keep client secrets and private keys out of mobile binaries and source control.
- [ ] Request least-privilege scopes for the intended API.
- [ ] Do not log access tokens, ID tokens, refresh tokens, authorization codes, or passwords.
- [ ] Test interactive sign-in, cancellation, callback routing, silent renewal, interaction-required handling, account removal, and sign-out.
- [ ] Test with a customer identity in the External ID tenant; a workforce tenant test does not prove CIAM compatibility.
- [ ] Validate the chosen native-auth or browser-delegated flow against the tenant's actual configuration.
- [ ] Run the repository's existing CI and iOS/macOS test suites on supported Apple build infrastructure before release.

## 9. Values required to complete tenant-specific validation

The following are intentionally not invented or committed:

| Setting | Required value |
|---|---|
| External ID tenant subdomain | `<TENANT_SUBDOMAIN>` |
| Tenant (directory) ID | `<TENANT_ID>` |
| Application (client) ID | `<CLIENT_ID>` |
| iOS bundle identifier | `<BUNDLE_ID>` |
| Registered redirect URI | Exact value from app registration |
| API scope(s) | Exact delegated scope(s) exposed by the target API |
| Authentication experience | Browser-delegated MSAL or configured native authentication |

Until these values and the tenant's selected authentication experience are supplied, the guide is ready for integration but live tenant authentication cannot be truthfully marked verified.
