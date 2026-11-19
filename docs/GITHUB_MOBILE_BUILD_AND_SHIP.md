# Build MSAL from GitHub on a phone or Windows PC

The manual **Build MSAL Apple Frameworks** workflow uses a GitHub-hosted macOS runner. You can start it from GitHub in a mobile browser or the GitHub mobile app; your Windows laptop does not need Xcode or a Mac build environment.

## Run a build

1. Merge this workflow into the repository's default branch (`dev`). GitHub only enables manual workflow runs after the workflow file is present on the default branch.
2. Open the repository in GitHub and select **Actions**.
3. Choose **Build MSAL Apple Frameworks**, then **Run workflow**.
4. Choose the branch whose code you want to build and start the workflow.
5. Open the completed run and download the **MSAL-Apple-XCFramework-…** artifact.

The workflow runs the iOS and macOS framework tests, archives MSAL for iOS devices, iOS simulators, and macOS, then packages those frameworks into `MSAL.xcframework.zip`. The artifact remains available for 30 days.

## What this delivers

The artifact is an unsigned XCFramework build for integrating into and testing an app. It does not publish a GitHub Release, sign an app, submit an app to the App Store, or create Azure resources. Those actions need a version/release decision and, for app distribution, Apple signing credentials and the target app's release configuration.

This repository is an authentication library, not an app to deploy to Azure App Service. The Azure and GitHub card in the portal is a product overview; it is not needed for this GitHub Actions build flow.
