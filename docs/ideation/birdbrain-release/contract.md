# Contract: Birdbrain Release Pipeline

## Problem

Birdbrain builds locally but has no way to distribute to others. Coworkers and friends need to be able to download a working .app from GitHub without building from source. There's also no documentation on the Gatekeeper workaround required for unsigned apps.

## Goals

1. **GitHub Actions release workflow** — On push of a `v*` tag, CI builds Birdbrain.app on a macOS runner, zips it, and creates a GitHub Release with the artifact attached.
2. **README** — Project documentation covering install, usage, architecture, and troubleshooting (handled by readme-writer agent, not in this spec).
3. **Gatekeeper documentation** — Clear instructions for unsigned app distribution. No code signing for v1, but document the path for future notarization.

## Success Criteria

- [ ] `git tag v0.1.0 && git push --tags` triggers a GitHub Actions workflow
- [ ] Workflow builds on `macos-latest`, produces `Birdbrain-v0.1.0-macos.zip`
- [ ] GitHub Release is created with the zip attached and auto-generated release notes
- [ ] A user can download the zip, extract it, right-click > Open to bypass Gatekeeper, and launch Birdbrain
- [ ] README includes clear Gatekeeper bypass instructions with screenshots description
- [ ] Future signing path is documented (in README or CONTRIBUTING)

## Scope

### In Scope
- `.github/workflows/release.yml` — build + release workflow
- Makefile target for creating the distributable zip
- Gatekeeper bypass instructions in README
- `xattr -cr` tip for terminal-comfortable users

### Out of Scope
- Code signing / notarization (no Apple Developer account yet)
- DMG packaging
- Auto-update from GitHub Releases (current brew-based updates are sufficient)
- Linux / Windows builds
- README content (parallel workstream)

## Execution Plan

### Dependency Graph

```
[Spec: Release Pipeline] — single phase, no dependencies
[README] — parallel, handled by readme-writer agent
```

### Execution Steps

1. Implement the release pipeline spec (below)
2. README is being written in parallel by the readme-writer agent
