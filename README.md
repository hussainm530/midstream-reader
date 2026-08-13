# Midstream — a reading app for the iPad mini 2

A native iOS reader for the PhD reading queue, built because the frictions that
actually bite are workflow frictions GoodReader cannot fix: no timer in the
reader, having to leave the paper to sync, the reading guide stranded on another
device, and a comment box the keyboard covers.

Tracked in [PKM-GIT #615](https://github.com/hussainm530/PKM-GIT/issues/615).

*Scaffolded by Claude — not yet built or run on the device. Every claim below
about behaviour is a design intention, not a verified result.*

---

## Why native rather than a web app

The web path (Path A in #615) was strong at the desk and weakest exactly where
GoodReader is strongest: offline. Its annotations would have lived in
Cache/IndexedDB, which iOS evicts on undocumented terms — and iOS 12 predates
most of the reporting on how service workers behave there.

Native removes the question entirely. Annotations live in the app's Documents
directory, a real filesystem iOS does not evict. The app is fully usable with
the ThinkPad switched off, and sync is a background convenience rather than a
precondition.

## What it does

| Friction | Fix |
|---|---|
| No timer while reading | `RepTimerView` — starts on open, counts against the rep's target, writes real minutes to the Rep Log |
| Must exit the paper to sync | Annotations POST as they are made; there is no sync step to leave the document for |
| Reading guide on another device | `GuideDrawer` — collapsible overlay from the trailing edge |
| Keyboard covers the comment box | `CommentComposer` pins to the real keyboard frame and animates with it |
| Typing is painful | Category chips (one tap), comment-free highlights default to Quote, and hold-to-record voice notes |
| Sync blocks the app | Background `URLSession`, 8-second timeouts, silent failure |

### Voice notes rather than dictation

iOS dictation on an A7 is mediocre, and Moonshine — the transcriber already used
for the voice-review pipeline — cannot run on 1 GB of RAM. So the app **records
and defers**: hold the mic, speak, and the m4a syncs to the ThinkPad where
Moonshine transcribes it into the annotation.

The trade-off is honest: the annotation is unreadable until it syncs and is
transcribed. For a paragraph of thinking on a train, that still beats two thumbs
on a 7.9" screen.

Note this does **not** solve swipe typing. Third-party keyboards are an OS-level
feature and iOS 12 predates QuickPath; no app can change that. What this can do
is make typing rare.

## Constraints the hardware imposes

iPad mini 2 · A7 · 1 GB RAM · **iOS 12.5.8**

- **No SwiftUI** (iOS 13+). UIKit throughout.
- **No scene lifecycle** (iOS 13+). Classic `AppDelegate` + `UIWindow`.
- **No semantic colours** (`UIColor.label` etc., iOS 13+). Literal colours only.
- **PDFKit is available** (iOS 11+) — which is what makes this tractable at all.

## Building

No Mac required. GitHub Actions builds an unsigned `.ipa`; AltStore on Windows
signs it with a free Apple ID at install time.

```
Push to main  →  macos-14 runner, Xcode 15.4  →  Midstream.ipa artifact
                 → download → AltServer (Windows) → iPad
```

**The Xcode pin is load-bearing.** Xcode 16 states iOS 15 as its minimum
deployment target and there are reports of its builds crashing on iOS 12.
Xcode 15 still officially supports an iOS 12 target, hence `macos-14`.

**This has an expiry date.** macOS 13 runners were retired in December 2025 and
macOS 14 is scheduled to be fully unsupported by **November 2026**. When that
lands, the options are a self-hosted runner, or building with Xcode 16 and
testing hard on the device. The CI has a deployment-target guard that fails the
build rather than shipping an .ipa that installs and then refuses to launch.

### Signing reality

A free Apple ID gives **7-day provisioning profiles**, so the app needs
re-signing weekly — AltStore automates this over Wi-Fi while on the same
network. A paid account ($99/yr) makes it yearly. AltStore requires iOS 12.2 or
later; the iPad's 12.5.8 clears that, though which AltStore *client* build still
supports iOS 12 needs confirming at install time.

## Server side

The app expects a small API on the ThinkPad at `100.117.163.83:8761`, extending
`System/Scripts/reader_prototype.py`:

| Endpoint | Purpose |
|---|---|
| `GET /api/library` | Queue: key, title, filename, page offset, guide, rep minutes |
| `GET /pdf/<filename>` | The cropped PDF (already implemented, with Range support) |
| `POST /api/annotations` | One annotation, pushed as made |
| `POST /api/sync` | Batch of annotations + reps accumulated offline |
| `POST /api/voice/<name>` | Voice note audio, for Moonshine transcription |

**Not yet written.** Only `GET /pdf/` exists today.

## Status

Scaffold only. Nothing has been compiled — there is no Mac in this setup, so the
first real signal is the first CI run. Expect compile errors on the first pass.
