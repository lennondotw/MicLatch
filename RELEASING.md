# Release Workflow

## Architecture

```
Local (your Mac)                     GitHub
─────────────────                    ──────────────────────────
1. bump version/build
2. archive + sign (Developer ID)
3. zip + notarize (Apple)
4. gh release create ──────────────► GitHub Release (zip)
                                         │
                                         ▼
                                     deploy-appcast.yml
                                     ├─ download zip
                                     ├─ generate appcast.xml
                                     └─ push to gh-pages branch
                                              │
                                              ▼
                                     GitHub Pages (auto-deploy)
                                     lennondotw.github.io/
                                     └─ appcast.xml ◄── Sparkle checks this
```

**Local**: code signing + notarization (requires Developer ID certificate and Apple credentials)
**CI**: appcast generation + Pages deployment (requires Sparkle EdDSA private key only)

## Prerequisites (One-Time Setup)

### Local

```bash
# 1. Store Apple notarization credentials
just setup-notarization your@email.com

# 2. Generate Sparkle EdDSA key pair
just sparkle-generate-keys

# 3. Export private key for backup and CI
build/sparkle-tools/bin/generate_keys -x build/sparkle_private_key --account miclatch-ed25519
```

### GitHub

1. **Secret**: Settings → Secrets and variables → Actions → New repository secret
   - Name: `SPARKLE_PRIVATE_KEY`
   - Value: contents of `build/sparkle_private_key`

2. **Pages**: Settings → Pages → Build and deployment
   - Source: **Deploy from a branch**
   - Branch: `gh-pages` / `/ (root)`

## Release Steps

> [!IMPORTANT]
> **Always bump both version AND build number!** Sparkle uses `CFBundleVersion` (build number)
> as the unique identifier. If you forget to bump the build number, the CI will fail with
> "Build number already exists in appcast.xml" error.

```bash
# 1. Bump version and build number (BOTH are required!)
just bump-version patch    # or: major | minor | 1.2.3
just bump-build            # ⚠️ DO NOT SKIP THIS!

# 2. Regenerate Xcode project
just generate

# 3. Build, sign, zip, notarize
just release

# 4. Create GitHub Release (triggers appcast deploy automatically)
gh release create v$(just version | cut -d' ' -f1) \
  build/MicLatch-$(just version | cut -d' ' -f1).zip \
  --title "v$(just version | cut -d' ' -f1)" \
  --notes "Release notes here"
```

Step 4 triggers the `deploy-appcast` workflow which:

- Downloads the zip from the release
- Fetches the existing appcast from GitHub Pages (preserves history)
- Generates an updated `appcast.xml` with Sparkle EdDSA signature
- Deploys to GitHub Pages

Users running the app will receive an update notification on next check.

## What Lives Where

| Artifact            | Location                       | In Git?            |
| ------------------- | ------------------------------ | ------------------ |
| Source code         | GitHub repo                    | Yes                |
| Release zip         | GitHub Releases                | No (binary)        |
| appcast.xml         | `gh-pages` branch → Pages      | Yes (with history) |
| Sparkle private key | Local Keychain + GitHub Secret | No                 |
| Developer ID cert   | Local Keychain                 | No                 |
| Apple credentials   | Local Keychain                 | No                 |

## Verifying a Release

```bash
# Check appcast is live
curl -sL https://lennondotw.github.io/MicLatch/appcast.xml

# Check zip is downloadable
curl -sIL https://github.com/lennondotw/MicLatch/releases/download/v0.1.0/MicLatch-0.1.0.zip | head -3

# Check CI deployment log
gh run list --workflow=deploy-appcast.yml --limit 1
```

## Key Rotation

If the Sparkle EdDSA private key is compromised:

1. Generate a new key pair: `just sparkle-generate-keys`
2. Update `SPARKLE_PUBLIC_KEY` in `project.yml` with the new public key
3. Update the `SPARKLE_PRIVATE_KEY` GitHub Secret
4. Release a new version — users on the old version can still update because Sparkle verifies against the key embedded in _their_ installed app, so you must publish one final release signed with the **old** key that embeds the **new** public key
