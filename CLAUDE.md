# CLAUDE.md — Midstream reader

Guidance for Claude Code working in this repo. Read before changing anything.

## What this is

A native iOS reader for the PhD reading queue, targeting an **iPad mini 2 on
iOS 12.5.8**. Tracked in [PKM-GIT #615](https://github.com/hussainm530/PKM-GIT/issues/615);
full status in the vault at `Projects/PhD/Literature/_reader-app-tracker.md`.

This repo is **not** the PKM vault. The vault's one-writer rule (ThinkPad owns
all writes) does **not** apply here — that rule exists to stop two clones
committing to the vault branch. Either machine may commit and push here.

## Non-negotiable constraints

The hardware cannot go past iOS 12.5.8. Everything below follows from that, and
none of it is a style preference:

- **No SwiftUI, no scene lifecycle, no semantic colours** (`UIColor.label` and
  friends) — all iOS 13+. UIKit, classic `AppDelegate`, literal colours.
- **Deployment target stays 12.0.** CI fails the build if `MinimumOSVersion` is
  not 12.x. Do not "fix" that guard by relaxing it.
- **Three pinned versions move together:** `macos-14` runner, Xcode 15.4,
  XcodeGen 2.40.1. Unpinning any one breaks the build in a way that reports as
  `xcodebuild: error: Unable to read project`, which names no version and looks
  like a corrupt file. Read the comments in `.github/workflows/build.yml`
  before touching them.
- **`.claude/` is gitignored and must stay that way.** A tracked
  `settings.local.json` already caused silent permission loss across machines
  once; see Node-Map in the vault.

## Architecture

Offline-first. `Store` owns everything in the app's Documents directory — a
real filesystem iOS does not evict, which is the whole reason this is native
rather than a web app. `SyncClient` is opportunistic: it fails fast and silently
when the ThinkPad is unreachable, and **nothing about reading may ever depend on
it**. If you find yourself adding a blocking sync, a spinner, or a modal that
interrupts reading, you have reintroduced the exact friction this app exists to
remove.

Server side lives in the vault: `System/Scripts/ipad/reader_server.py`, port
8761 on `100.117.163.83`.

## Verified vs. assumed

**Verified:** CI green, `MinimumOSVersion = 12.0`, zero warnings; server
endpoints tested including Range, path traversal and idempotent re-push;
Xcode 16.4 canary produces `minos 12.0` with the Swift runtime bundled.

**Assumed — nothing has ever run on the device.** That it launches, that PDFKit
selection is usable at 7.9", that the keyboard-frame pinning works on iOS 12.
Do not describe any of it as working.

## Working here

```bash
gh run list --limit 3          # CI status
gh run view <id> --log-failed  # why a build failed
```

There is no local build — no Mac in this setup. CI is the only compiler, so
every change is validated by pushing. Keep commits small for that reason.

When a build fails, read the actual log before theorising. The two failure modes
so far both reported as something other than their cause.
