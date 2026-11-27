# WorkOS AuthKit with the iOS External ID sample

Add WorkOS AuthKit as a sign-in option in a dedicated Microsoft Entra External ID test tenant. Use the Objective-C sample's existing **External ID** button. Entra opens the WorkOS-hosted sign-in page, redeems the WorkOS authorization code on the server, validates the upstream ID token, and issues the Entra tokens that MSAL already uses. The WorkOS Connect client secret and provider tokens stay in the managed services. AuthKit manages its hosted browser session on its own origin.

This is a tenant configuration integration. The Apple app uses MSAL and its existing Keychain cache for Entra tokens. The setup requires zero WorkOS environment variables, API keys, or additional SDKs in the app. Use the deployed WorkOS and Microsoft documentation below as the setup reference. The documented protocols align. A staging sign-in is required to verify interoperability.

## Set up WorkOS staging

1. In WorkOS Dashboard, select a staging environment. Copy its public AuthKit origin, for example `https://<staging-subdomain>.authkit.app`, without a trailing slash. Use separate staging test accounts and restrict who can sign up using the staging AuthKit policy.
2. Under **Connect**, create a **first-party, confidential OAuth application** for the staging Entra tenant. Use the authorization-code flow.
3. Register these exact HTTPS redirect URIs after substituting the staging Entra tenant's subdomain and directory (tenant) ID:

   ```text
   https://<tenant-subdomain>.ciamlogin.com/<tenant-ID>/federation/oauth2
   https://<tenant-subdomain>.ciamlogin.com/<tenant-subdomain>.onmicrosoft.com/federation/oauth2
   ```

4. Copy the **Connect application client ID** and pass the generated Connect secret directly to the Entra provider configuration through the approved secret-handling process. Keep the secret out of the app's plist and build settings, environment files, command history, support tickets, and logs.

[WorkOS Connect OAuth applications](https://workos.com/docs/authkit/connect/oauth) · [WorkOS environments](https://workos.com/docs/authkit/environments) · [Microsoft federation callbacks](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-custom-oidc-federation-customers)

## Add the identity provider in Entra staging

In the **test external tenant**, use an authorized **External Identity Provider Administrator** to open **External Identities → All identity providers → Custom → Add new → Open ID Connect**. Configure these fields.

| Setting | Value |
| --- | --- |
| Display name | WorkOS AuthKit (Staging) |
| Well-known endpoint | `https://<staging-subdomain>.authkit.app/.well-known/openid-configuration` |
| OpenID issuer URI | The exact WorkOS discovery `issuer` |
| Client ID | WorkOS Connect OAuth application client ID |
| Client authentication | `client_secret_post` |
| Client secret | Staging WorkOS Connect secret, entered in Entra |
| Scope | `openid profile email` |
| Response type | `code` |
| Claims mapping | `sub`, `name`, `given_name`, `family_name`, `email`, `email_verified` to the corresponding standard fields |

Request only the scopes shown. Omitting `offline_access` avoids requesting an upstream refresh token. Add the new provider alongside the existing providers in the test sign-up/sign-in user flow that serves the staging iOS app registration. Configure the local sample with that Entra registration's client ID, authority, exact registered Apple redirect URI, and delegated scopes, following the [sample setup](EXTERNAL_ID_BROWSER_DELEGATED_IOS.md). The HTTPS federation callbacks are registered in WorkOS. The Apple `msauth` callback is registered in Entra and the app.

[Microsoft custom OIDC setup](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-custom-oidc-federation-customers) · [Microsoft claims mapping](https://learn.microsoft.com/en-us/entra/external-id/customers/reference-oidc-claims-mapping-customers) · [WorkOS discovery](https://workos.com/docs/reference/workos-connect/metadata) · [WorkOS token claims](https://workos.com/docs/reference/workos-connect/token)

## Keep authentication separate from permissions

Use the federated subject as identity metadata and the existing Entra account and resource authorization policies for access. Avoid linking identities or assigning roles based on email address, email domain, WorkOS organization, or upstream role claims. An authorized owner or administrator must explicitly grant privileged access through the existing Entra or resource role assignment, record the grant, and review the corresponding audit event. Authentication through WorkOS grants only the access already authorized for the Entra account.

The fork has a public client, a proof-of-possession flow, and delegated API calls. Its tracked code has no third-party service API or organization-to-resource grants. Keep Connect M2M unconfigured. A future M2M integration requires a named third-party service, a protected API, and explicit client-to-organization, scope, and resource grants enforced by that API. Device authorization is a user flow and stays separate from service credentials.

[WorkOS Connect M2M use cases](https://workos.com/docs/authkit/connect/m2m) · [MSAL authentication flows](https://learn.microsoft.com/en-us/entra/msal/msal-authentication-flows)

## Validate staging

Check the public discovery settings and run the offline unit tests from the repository root. The command takes only the staging AuthKit origin.

```bash
python3 -B -m unittest discover -s scripts/tests -p test_check_workos_oidc.py -v
python3 -B scripts/check_workos_oidc.py 'https://<staging-subdomain>.authkit.app'
```

The discovery check verifies the exact issuer, documented endpoints, confidential client authentication method, and advertised signing algorithm. The following acceptance checks require the staging tenants and a supported Apple runner or device:

| Case | Expected outcome |
| --- | --- |
| External ID → WorkOS AuthKit | A staged test user returns through the registered Apple callback. MSAL gets an Entra account and a token for the configured delegated API. Silent acquisition uses that account. |
| Existing sign-ins and account features | Workforce and existing External ID providers still sign in. Exercise provider-hosted passkeys and recovery, where enabled. Exercise the existing RSA proof-of-possession, native password-reset, and device flows wherever configured. |
| Cancellation or provider denial | No new app account or session is established. Starting another sign-in still works. |
| Wrong callback or missing, mismatched, or replayed state | The staging transaction is rejected and creates no app session. Check both callback legs and confirm the managed upstream flow sends state and nonce. MSAL manages PKCE on the app-to-Entra leg. Verify upstream S256 support and use in the staging exchange, where supported by the managed provider. |
| Expired code or invalid, expired, wrongly issued, or wrong-audience upstream ID token | Entra denies sign-in and issues no app token. Use provider-supported staging fixtures for invalid token claims and record cases the managed providers cannot exercise. |
| User in a different organization or unassigned user | A user outside the configured staging access policy cannot access its protected resource. Verify denial at the resource when one is in scope. A successful federated login alone is insufficient. |
| Unauthorized administration | A new federated user and a test user with an admin-like email are denied a staging admin-only action. Verify any explicit, authorized role grant separately through Entra or resource audit logs. |
| Sign-out and re-entry | The sample removes the selected External ID account from its MSAL cache. Check whether the next sign-in reuses the hosted browser session and document the staging behavior. |

Use sanitized error categories and request correlation IDs for troubleshooting. Avoid collecting raw callback URLs, authorization codes, response bodies, tokens, cookies, or secrets. Record the exact tests exercised. The tenant and resource checks are separate from the offline discovery tests.

## Rotate or roll back

For planned rotation, create a replacement WorkOS Connect secret. Update the confidential credential in the Entra test provider, verify a fresh login, then delete the old WorkOS secret. For credential exposure, disable the affected route and revoke the old secret promptly. Review the WorkOS and Entra audit records and revoke affected sessions or resource access under the respective provider policies. A secret revocation does not replace session or access revocation.

To roll back, remove the WorkOS provider from the staging user flow, check an existing provider login, and revoke the WorkOS Connect secret. Review staged accounts and disable any access granted only for the test. Keep an existing administrator sign-in method available during setup, rotation, and rollback.

[WorkOS Connect secret lifecycle](https://workos.com/docs/reference/workos-connect/applications/client-secrets)
