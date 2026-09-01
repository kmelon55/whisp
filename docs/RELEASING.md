# Releasing Whisp

Tagged releases always require a Sparkle EdDSA signature. When Apple signing credentials are configured, the DMG is additionally signed with a Developer ID Application certificate, submitted to Apple's notary service, and stapled with the resulting ticket. Without those optional Apple credentials, the workflow publishes an ad-hoc signed build and users may need to allow it through **System Settings → Privacy & Security → Open Anyway**.

The optional Developer ID path requires active [Apple Developer Program](https://developer.apple.com/programs/) membership. Create the Developer ID Application certificate in Certificates, Identifiers & Profiles and create a team App Store Connect API key with access to the notary service.

## GitHub Actions secrets

`SPARKLE_PRIVATE_KEY` is required for every release. The six Apple credentials are optional, but must be configured as a complete group when Developer ID signing and notarization are enabled.

| Secret | Value |
| --- | --- |
| `SPARKLE_PRIVATE_KEY` | Existing Sparkle EdDSA private key; required |
| `DEVELOPER_ID_P12_BASE64` | Optional base64-encoded Developer ID Application `.p12` export |
| `DEVELOPER_ID_P12_PASSWORD` | Password used when exporting the `.p12` |
| `DEVELOPER_ID_APPLICATION` | Full signing identity, such as `Developer ID Application: Name (TEAMID)` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded App Store Connect API `.p8` key |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |

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
6. Confirm that GitHub Actions generated the signed Sparkle appcast and published the release. When Apple credentials are configured, also confirm Developer ID signing, notarization, stapling, and Gatekeeper validation.

The appcast must be generated after stapling because stapling changes the DMG bytes that Sparkle signs.
