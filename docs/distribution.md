# Distribution

This project can be built from source by anyone with macOS and the Xcode Command Line Tools. A shareable binary release requires Apple Developer signing and notarization.

## Source Builds

```sh
git clone https://github.com/Jdjohnson/formatter.git
cd formatter
./script/build_and_run.sh
```

That creates and opens:

```text
dist/Formatter.app
```

## Binary Releases

Apple requires directly distributed macOS apps to be signed with a Developer ID Application certificate and notarized before users can open them without Gatekeeper warnings.

The release script handles the project side of that workflow:

```sh
./script/package_release.sh --notary-profile FormatterNotary
```

It will:

- Build in release mode.
- Create `dist/release/Formatter.app`.
- Sign with hardened runtime.
- Include the Apple Events entitlement used by the browser URL fallback.
- Zip the app for notarization.
- Submit with `notarytool`.
- Staple and validate the notarization ticket.
- Re-zip the stapled app as `dist/release/Formatter-0.1.0.zip`.
- Validate with `spctl`.

## One-Time Maintainer Setup

1. Create or install a `Developer ID Application` certificate from Apple Developer.
2. Create an app-specific Apple password or App Store Connect API key.
3. Store notarization credentials in Keychain:

```sh
xcrun notarytool store-credentials FormatterNotary \
  --apple-id APPLE_ID \
  --team-id TEAM_ID \
  --password APP_SPECIFIC_PASSWORD
```

4. Run:

```sh
FORMATTER_TEAM_ID=TEAM_ID ./script/package_release.sh --notary-profile FormatterNotary
```

## References

- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple Events Entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.automation.apple-events)
