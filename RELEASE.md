# Releasing hjkl

hjkl ships as a Developer ID app: signed with a Developer ID Application
certificate, notarized by Apple, and stapled. This is direct distribution, not
the App Store. Gatekeeper accepts it on any Mac once notarized.

`scripts/release.sh` runs the whole pipeline. It refuses to start and prints
guidance if anything is missing, so it is safe to run before you have the
certificate.

## Prerequisites

1. **Apple Developer Program membership.** Required to issue a Developer ID
   certificate. Enroll at https://developer.apple.com/programs/.

2. **Developer ID Application certificate** in your login keychain. Create it in
   Xcode (Settings > Accounts > team > Manage Certificates > "+" > Developer ID
   Application) or at
   https://developer.apple.com/account/resources/certificates and import it.
   Confirm:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

3. **notarytool keychain profile.** Store credentials once so the script can
   notarize without prompting. Generate an app-specific password at
   https://appleid.apple.com (Sign-In and Security > App-Specific Passwords),
   then:

   ```sh
   xcrun notarytool store-credentials hjkl-notary \
     --apple-id <your-apple-id-email> \
     --team-id <TEAM_ID> \
     --password <app-specific-password>
   ```

## Environment variables

| Var | Required | Default | Meaning |
|-----|----------|---------|---------|
| `TEAM_ID` | yes | none | Apple Team ID (10 chars). Find it at https://developer.apple.com/account under Membership. |
| `NOTARY_PROFILE` | no | `hjkl-notary` | Name of the notarytool keychain profile created above. |

## Running

```sh
export TEAM_ID=ABCDE12345
./scripts/release.sh
```

The script generates the Xcode project, archives Release with Hardened Runtime,
exports a Developer ID signed `.app`, zips it, submits to notarytool and waits,
staples the ticket, then verifies with `codesign` and `spctl`. The final stapled
app lands at `build/export/hjkl.app`.

## Signing and entitlements

- **Hardened Runtime is on** (`ENABLE_HARDENED_RUNTIME=YES`, plus
  `--options runtime --timestamp`). Notarization requires it.
- **`hjkl.entitlements` is an empty `<dict/>`.** A non-sandboxed Developer ID app
  needs no entitlement to read user files, and Hardened Runtime needs no extra
  entitlement for this app. Do not add
  `com.apple.security.cs.disable-library-validation` unless a signed-but-foreign
  dylib actually fails to load under Hardened Runtime.
- **No App Sandbox.** hjkl reads arbitrary `~/.config` files, which the sandbox
  would block. Developer ID distribution does not require the sandbox (the App
  Store would).

## Accessibility / Input Monitoring

hjkl needs Accessibility and Input Monitoring at runtime to read keystrokes.
These are **not entitlements**. The user grants them through System Settings >
Privacy & Security (TCC) on first run. Signing identity stays stable across
releases so the grant survives updates; resigning with a different identity
resets the TCC grant.

## Distribution

The stapled `.app` is ready to run. For delivery, package it: build a DMG
(e.g. `create-dmg`) or zip the stapled `.app`. If you ship a DMG, notarize the
DMG as well.

## Future: auto-update

Add [Sparkle](https://sparkle-project.org/) for in-app auto-update. It works
with Developer ID apps, signs its own update archives (EdDSA), and fits the
non-sandboxed agent model. Not wired up yet.
