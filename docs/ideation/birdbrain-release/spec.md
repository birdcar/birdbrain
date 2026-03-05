# Implementation Spec: Birdbrain Release Pipeline

**Contract**: ./contract.md
**Estimated Effort**: S

## Technical Approach

Create a single GitHub Actions workflow triggered by `v*` tags. The workflow runs on `macos-latest` (Apple Silicon), executes the existing `make build`, zips the resulting `.app`, and publishes it as a GitHub Release using `softprops/action-gh-release`. The Makefile gets a new `dist` target that produces the distributable zip.

For Gatekeeper: since the app is unsigned, macOS will quarantine it on download. Users need to either right-click > Open or run `xattr -cr Birdbrain.app` to clear the quarantine attribute. This is standard for unsigned open-source macOS apps and well-documented in the README (handled by the parallel readme-writer agent).

## Feedback Strategy

**Inner-loop command**: `act -j release --dryrun` (if `act` is installed) or push a test tag to a branch

**Playground**: GitHub Actions — push a `v0.0.1-test` tag to trigger the workflow and verify the release appears.

**Why this approach**: CI/CD workflows can only be fully validated by running them. Local validation is limited to YAML syntax checks.

## File Changes

### New Files

| File Path | Purpose |
| --- | --- |
| `.github/workflows/release.yml` | Build and release workflow triggered on `v*` tags |

### Modified Files

| File Path | Changes |
| --- | --- |
| `Makefile` | Add `dist` target that builds and zips the .app for distribution |

## Implementation Details

### 1. GitHub Actions Release Workflow

**Overview**: Single workflow file that builds Birdbrain.app on macOS and publishes as a GitHub Release.

**`.github/workflows/release.yml`**:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    name: Build and Release
    runs-on: macos-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Extract version from tag
        id: version
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Update Info.plist version
        run: |
          /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${{ steps.version.outputs.version }}" src/Info.plist
          /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${{ steps.version.outputs.version }}" src/Info.plist

      - name: Build
        run: make build

      - name: Create distributable zip
        run: make dist

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/Birdbrain-*.zip
          generate_release_notes: true
          draft: false
          prerelease: ${{ contains(github.ref_name, '-') }}
```

**Key decisions**:

- **`macos-latest`** — Apple Silicon runner, matches target architecture. Kitty DMG download in the Makefile fetches the universal binary so this works regardless.
- **Version extraction from tag** — Strips `v` prefix from tag (e.g., `v0.1.0` → `0.1.0`) and patches Info.plist before build. This means the app bundle always has the correct version.
- **`softprops/action-gh-release`** — Most widely used release action. `generate_release_notes: true` auto-generates notes from commits since last tag. Tags containing `-` (like `v0.1.0-beta`) are marked as prerelease.
- **`permissions: contents: write`** — Required for creating releases. Scoped to just this workflow.

### 2. Makefile `dist` Target

**Overview**: New target that creates a distributable zip from the built .app.

**Addition to Makefile**:

```makefile
dist: build
	@echo "→ Creating distributable zip..."
	@cd build && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME).app" "$(APP_NAME)-v$(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ../src/Info.plist)-macos.zip"
	@echo "✓ Created build/$(APP_NAME)-v*-macos.zip"
```

**Key decisions**:

- **`ditto`** instead of `zip` — macOS-native tool that properly handles resource forks, extended attributes, and symlinks in `.app` bundles. `zip` can corrupt macOS app bundles.
- **Version in filename** — Extracted from Info.plist (which CI patches from the tag). Produces `Birdbrain-v0.1.0-macos.zip`.
- **`--keepParent`** — Includes the `Birdbrain.app` directory in the zip root, so extracting gives you the .app directly.

## Gatekeeper Analysis

### What happens when a user downloads an unsigned .app

1. **Safari/Chrome downloads the zip** → macOS adds `com.apple.quarantine` extended attribute
2. **User extracts the zip** → quarantine attribute propagates to Birdbrain.app
3. **User double-clicks Birdbrain.app** → Gatekeeper blocks: "Birdbrain can't be opened because Apple cannot check it for malicious software"
4. **No "Open Anyway" button** on first attempt

### How users bypass Gatekeeper (documented in README)

**Method 1 (easiest for non-technical users)**:
- Right-click (or Control-click) on Birdbrain.app
- Click "Open" from the context menu
- Click "Open" in the dialog that appears
- Only needed once — subsequent launches work normally

**Method 2 (after failed double-click)**:
- System Settings → Privacy & Security
- Scroll down to see "Birdbrain was blocked from use because it is not from an identified developer"
- Click "Open Anyway"
- Enter password

**Method 3 (terminal)**:
```bash
xattr -cr /Applications/Birdbrain.app
```

### Future signing path (document, don't implement)

When ready to eliminate the Gatekeeper friction:

1. **Apple Developer Program** — $99/year at developer.apple.com
2. **Developer ID Application certificate** — Created in Xcode or developer portal
3. **Code sign the .app** — `codesign --deep --force --verify --verbose --sign "Developer ID Application: Name (TEAM_ID)" Birdbrain.app`
4. **Notarize** — `xcrun notarytool submit Birdbrain.zip --apple-id EMAIL --team-id TEAM_ID --password APP_SPECIFIC_PASSWORD --wait`
5. **Staple** — `xcrun stapler staple Birdbrain.app`
6. **Update CI** — Store signing cert as GitHub secret, add signing + notarization steps to the workflow

This can be added to the release workflow later by adding secrets for the certificate and notarization credentials.

## Testing Requirements

### Manual Testing

- [ ] `make dist` produces a correctly named zip in `build/`
- [ ] Extracted zip contains `Birdbrain.app` at the root
- [ ] Push a test tag (`v0.0.1-test`) to GitHub → workflow triggers
- [ ] Workflow completes on macOS runner
- [ ] GitHub Release is created with zip attached
- [ ] Release is marked as prerelease (because tag contains `-`)
- [ ] Download zip on a different Mac → right-click > Open works
- [ ] After Gatekeeper bypass, Birdbrain launches normally

## Validation Commands

```bash
# Verify workflow YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"

# Build and create zip locally
make clean && make dist

# Verify zip contents
zipinfo build/Birdbrain-*.zip | head -20

# Verify zip extracts to a working .app
cd /tmp && unzip ~/Code/birdcar/birdbrain/build/Birdbrain-*.zip && ls Birdbrain.app/

# Test tag push (use a pre-release tag for safety)
git tag v0.0.1-test && git push origin v0.0.1-test
```

## Open Items

- [ ] Kitty DMG is ~38MB — CI will download it each run. Consider caching with `actions/cache` keyed on `KITTY_VERSION` if build times are slow.

---

_This spec is ready for implementation._
