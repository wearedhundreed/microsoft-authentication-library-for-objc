# Build MSAL from GitHub on a phone or Windows PC

The **Build MSAL Apple Frameworks** workflow is available on the repository's default branch, `dev`. It runs on a GitHub-hosted macOS runner, so you can build from GitHub on a phone or Windows laptop without Xcode locally.

## Run a build

1. Open `wearedhundreed/microsoft-authentication-library-for-objc` on GitHub and select **Actions**.
2. Choose **Build MSAL Apple Frameworks**, then **Run workflow**.
3. Select the branch to build. Choose `feature/external-id-browser-ios` for the External ID sample integration, or `dev` for the current default branch.
4. Start the workflow. When it completes, open the run and download its **MSAL-Apple-XCFramework-…** artifact.

The workflow runs iOS and macOS framework tests, archives frameworks for iOS devices, iOS simulators, and macOS, then packages them into `MSAL.xcframework.zip`. Artifacts are retained for 30 days.

## What this delivers

The artifact is an unsigned XCFramework for integrating into and testing an app. It does not publish a GitHub Release, sign an app, submit an app to the App Store, or create Azure resources. Those require release decisions and, for app distribution, Apple signing credentials and the target app's release configuration.

This repository is an authentication library, not an app to deploy to Azure App Service. The Azure and GitHub card in the portal is a product overview; it is not needed for this GitHub Actions build flow.