# Releasing

For the owner. A release is a version of `module.xml` on `master`, a Git tag, a GitHub release and the
package in the community IPM registry.

1. **Version.** `module.xml` `<Version>` is the release version (SemVer). `CHANGELOG.md` has a section for
   it; replace "(unreleased)" with the date.
2. **CI green on `master`.** All jobs: `unit-tests`, `ipm-install`, `ipm-upgrade`, `web`, `e2e`, `docker`.
3. **Tag and GitHub release** (from `master`):

   ```shell
   git tag -a v2.0.0 -m "IRIS History Monitor 2.0.0"
   git push origin v2.0.0
   gh release create v2.0.0 --title "2.0.0" --notes "<the CHANGELOG section>"
   ```

4. **Community registry (IPM).** Packages reach `pm.community.intersystems.com` through the app's page on
   [Open Exchange](https://openexchange.intersystems.com/): sign in as the owner, open IRIS History
   Monitor, and publish a new version from the GitHub repository. Open Exchange reads `module.xml` from
   `master`.
5. **Check the published package** on a clean instance:

   ```objectscript
   zpm "install iris-history-monitor"
   ```

   Open `/historymonitor/index.html` and sign in.
