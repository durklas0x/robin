# Robin workflow

## Development

- `project.yml` is the source of truth. Regenerate with `xcodegen generate` after changing targets, sources, or settings; generated Xcode projects and build output stay ignored.
- Use `Sources` for the menu-bar app, `FinderExtension` for the separate Finder Sync target, `Shared` for common code, and `Tests` for the RobinTests target. Include tested helpers in that target so tests have working indexing.
- Build and run from the same `build/` directory used by the VS Code tasks. Keep one Robin process and app registration active; temporary `.app` copies and paused debugger sessions can make macOS select an older extension.
- Run the test command in README’s **Build / release** section. Add focused tests for behavior and regressions; validate small visual changes in the running app. Refresh build-server metadata if indexing becomes stale.

## App verification

- Keep the UI compact and native. The location bar follows Finder; folder actions belong in the bar and Finder’s context menu. About opens only when explicitly selected, including when the app receives action URLs.
- Initial onboarding requires the Finder extension and Finder Automation before starting the bar. Persist unfinished progress; closing initial setup quits Robin. Replaying Setup & Tour keeps Robin running. Launch at login is optional; Terminal permission is requested on first use.
- Check Automation off the main thread. Recheck permissions when returning from settings and before completing setup; preserve the user’s permission choices.
- Diagnose extensions with `pluginkit -m -v -i com.durklas0x.Robin.Finder`. FinderSync can report false for an enabled extension: the fallback must recognize the selected, enabled copy at the current app’s exact path, rather than accepting an older copy elsewhere.
- Verify actual Finder behavior after integration changes: editable paths, focus loss, context-menu handoff, and the New File dialog. Keep settings windows out of action launches.
- Use the approved light/dark artwork. Both targets include the icon; the main app needs full standalone icon output for System Settings. Inspect compiled icons manually when changed; icon-specific tests stay out of the release workflow.

## Documentation and screenshots

- Keep README concise: overview, install, first-launch approval/setup, and developer commands. Describe implemented features only.
- Store screenshots in `docs/screenshots`. Preserve supplied shadows and screenshot content; use transparent backgrounds for cutouts. The bar preview sits above the tagline; the small, clickable context-menu preview follows the complete feature list.
- Use Markdown images for Codex preview compatibility. The SVG preview wrapper controls menu display size while linking to the full PNG.
- Current builds are ad-hoc signed and not notarized. Keep quarantine guidance scoped to the trusted Robin app; do not remove quarantine automatically.

## Release and Homebrew

1. When a release is requested, choose an unused version, update `MARKETING_VERSION`, increment `CURRENT_PROJECT_VERSION`, and update the workflow’s default version, README examples, and `.github/release-notes.md`.
2. Run tests and `git diff --check`, then commit and push the approved changes to `main` in `durklas0x/robin`. Use the `durklas0x` GitHub account; obtain its token through `gh auth token --user durklas0x` without printing it or changing global account selection.
3. Dispatch `.github/workflows/release.yml` with the version and watch it finish. It tests, builds Intel + Apple Silicon binaries, verifies version/signatures/architectures, and publishes the ZIP and SHA-256 file. If fixing a failed run, dispatch against the corrected commit.
4. Download the release and verify its checksum, bundle version, signature, and both architectures. Keep verification copies from competing with the working app: use a directory name without `.app` after inspection.
5. Refresh `durklas0x/homebrew-tap`, update `Casks/robin.rb` with the version and verified SHA-256, then commit and push. Refresh the local tap and run `brew audit --cask --strict durklas0x/tap/robin` and `brew fetch --cask durklas0x/tap/robin`.
6. Finish with the release link and `brew update` / `brew upgrade --cask durklas0x/tap/robin`. A release is complete when publishing and tap verification succeed.
