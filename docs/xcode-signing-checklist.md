# Xcode signing checklist

This project is configured as a macOS app targeting Ventura and newer. It builds cleanly without code signing, but a real Apple developer identity is still required for signed builds and publish workflows.

## Required before signed build or publish

1. Install a valid Apple developer certificate in Keychain Access.
   - Debug build: Apple Development certificate is typically used.
   - Release or distribution: Apple Distribution or Mac App Distribution certificate is typically used.

2. Confirm the team is valid for the app.
   - Set the DEVELOPMENT_TEAM value in the project settings to the correct Apple Developer Team ID.
   - Use the same team for Debug and Release unless the project intentionally uses different identities.

3. Ensure the provisioning profile matches the bundle identifier.
   - The app bundle identifier is: ergo.sum.coge.hexy-plexy
   - The profile must match this identifier and the selected signing identity.

4. Keep the bundle identifier stable.
   - Do not change the app ID without regenerating or updating the matching profile.

5. Validate entitlements.
   - The app uses Supporting/Hexy-Plexy.entitlements.
   - Ensure the entitlements remain compatible with the selected signing type and App Sandbox requirements.

## Xcode settings to verify

In Xcode, check the target settings for Hexy-Plexy:

- macOS deployment target: 13.0 or newer
- Signing: Automatically manage signing or set explicit signing identity
- Bundle identifier: ergo.sum.coge.hexy-plexy
- Team: valid Developer Team ID
- Code signing identity: valid certificate for the build type
- Provisioning profile: valid profile for the selected certificate and app ID

## Debug workflow

- Use a development certificate for local debugging.
- Run the app from Xcode with a valid Apple Development certificate installed.
- If the build fails with signing errors, check Keychain Access and the app’s signing identity.

## Release and publish workflow

- Use a distribution certificate for Release builds and packaging.
- Use a valid provisioning profile that matches the app bundle ID.
- For App Store or notarized distribution, also verify the required distribution and notarization setup.

## Publish profile note

A publish profile is not valid unless the installed certificate and the displayed profile match the app’s bundle ID and signing identity.

If the certificate is missing or expired, the project will fail in Xcode even though the code compiles.

## Quick verification checklist

- Certificate installed and trusted
- Team ID valid
- Bundle identifier matches profile
- Profile installed and selected
- Entitlements valid
- Release target set to 13.0 or newer
- Xcode build succeeds with signing enabled

## Typical failure signs

- “No signing certificate matches the provisioning profile”
- “The app bundle identifier does not match the profile”
- “A valid signing identity could not be found”
- “Provisioning profile is invalid or expired”

## Final rule

The source code and Xcode project are now aligned with the Ventura+ build requirement, but the signed app flow still depends on a valid Apple developer certificate and a matching publish profile.
