# Update from GitHub Releases with Sparkle

Follows ADR 0001: we own updates. Releases are published on GitHub Releases of the public repository (`.github/workflows/release.yml`, on a `v*` tag), and the app installs them with Sparkle 2: it reads the feed `releases/latest/download/appcast.xml`, shows the notes, downloads the zip, checks it and replaces the app. Sparkle already does the parts we must not get wrong (signature checks, replacing a running app, relaunching), so we do not write our own updater against the GitHub API.

Trust: the zip and the feed itself are EdDSA-signed with a key that never leaves the `release` environment's secrets and an offline backup (`SUPublicEDKey`, `SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`), and the new app must carry the same Developer ID as the installed one. Publishing therefore needs the tag ruleset, the environment's reviewer and both keys (README.md, Release security).

## Consequences

- typo now goes on the network: to fetch `appcast.xml` and, when the user installs an update, the zip from github.com. Nothing about the user is sent (no system profile); GitHub sees the request as for any download. ADR 0003 is unchanged: no typed text is involved.
- Automatic checks are the user's choice: Sparkle asks on the second launch, and Settings → General can change it. Unasked, typo only checks when the user picks **Check for Updates…**.
- A dockless app must not steal focus: a scheduled check shows its window only right after launch, otherwise the menu offers the update.
- Losing the Sparkle private key means installed copies can no longer be updated; it must be backed up.
- Builds from before 0.4.0 have no updater; testers install 0.4.0 by hand once.
