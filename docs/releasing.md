# Releasing

Releases follow the same flow as [sentai-task](https://github.com/musketeers-br/sentai-task): a merge to
`master` is a release.

1. **Every push to `master` publishes a version.** The `versionbump` workflow
   (`.github/workflows/bump-module-version.yml`) raises the patch of `<Version>` in `module.xml` and
   commits it as ProjectBot ("auto bump version to X.Y.Z"). Open Exchange follows the repository and
   publishes each new `module.xml` version to the community IPM registry (`pm.community.intersystems.com`).
2. **Minor and major versions are set by hand in the pull request.** A new feature raises the minor (2.1.0
   → 2.2.0), and a breaking change raises the major. When the push to `master` already changed `<Version>`,
   the workflow leaves it as it is, so that exact version is published. Give it a section in
   `CHANGELOG.md`. Patch versions need no entry of their own.
3. **Do not edit `<Version>` for a fix.** The bot raises the patch after the merge.
4. **CI must be green on the pull request** before merging: `unit-tests`, `ipm-install`, `ipm-upgrade`,
   `web`, `e2e`, `docker`.
5. **Optional: a GitHub release for minor and major versions.** Tag the bot's commit (or the merge, when
   the version was set by hand):

   ```shell
   git tag -a vX.Y.Z -m "IRIS History Monitor X.Y.Z"
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "X.Y.Z" --notes "<the CHANGELOG section>"
   ```

6. **Check the published package** on a clean instance:

   ```objectscript
   zpm "install iris-history-monitor"
   ```

   Then open `/historymonitor/index.html` and sign in.

## Open Exchange (once, by the owner)

Automatic publication is configured on the app's page on
[Open Exchange](https://openexchange.intersystems.com/), not in this repository. The app must be published
in the Package Manager and must follow the GitHub repository. Until it does, a version on `master` does
not reach the registry. Check with:

```shell
curl -s https://pm.community.intersystems.com/packages/iris-history-monitor
```

The `versions` list must include the version in `module.xml` on `master`.
