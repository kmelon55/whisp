# Releasing Whisp

Tagged releases are intentionally blocked unless the DMG can be signed with a Developer ID Application certificate, submitted to Apple's notary service, and stapled with the resulting ticket.

This requires active [Apple Developer Program](https://developer.apple.com/programs/) membership. Create the Developer ID Application certificate in Certificates, Identifiers & Profiles and create a team App Store Connect API key with access to the notary service.

## Required GitHub Actions secrets

Configure these repository secrets before pushing a release tag:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded Developer ID Application `.p12` export |
| `DEVELOPER_ID_P12_PASSWORD` | Password used when exporting the `.p12` |
| `DEVELOPER_ID_APPLICATION` | Full signing identity, such as `Developer ID Application: Name (TEAMID)` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded App Store Connect API `.p8` key |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |
| `SPARKLE_PRIVATE_KEY` | Existing Sparkle EdDSA private key |

Keep certificate files, private keys, and passwords out of the repository and chat messages. Store them only as encrypted repository secrets.

On macOS, encode the files without line wrapping:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

## Release process

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Update `RELEASE_NOTES.md`.
3. Run `swift build` and `./Scripts/test-core.sh`.
4. Commit and push the changes.
5. Push the matching tag, for example `v0.3.2`.
6. Confirm that GitHub Actions signed the app and DMG, notarized and stapled the DMG, validated it with Gatekeeper, generated the Sparkle appcast, and published the release.

The appcast must be generated after stapling because stapling changes the DMG bytes that Sparkle signs.
