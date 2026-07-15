---
title: My Mac had 14 GB free. Here's what was actually eating 250 GB
published: false
description: A developer's field guide to macOS disk junk — caches, node_modules, simulators, and the marker-file trick for finding build artifacts safely.
tags: macos, devtools, productivity, swift
# cover_image: https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/u12rrq0n8ac7mxeq7p72.png
# Use a ratio of 100:42 for best results.
# published_at: 2026-07-14 21:10 +0000
---

![Image description](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/u12rrq0n8ac7mxeq7p72.png)

Last week my MacBook greeted me with the classic: **"Your disk is almost full."** 460 GB drive, 14 GB free. I hadn't downloaded a single movie. I don't keep my photo library on this machine. So where did almost half a terabyte go?

I decided to actually find out instead of just deleting my Downloads folder and hoping. What I found was equal parts fascinating and embarrassing, and I think every developer's Mac looks roughly the same. Here's the full breakdown — and the commands so you can audit yours.

## Step 1: Measure before you delete

The golden rule of disk cleanup: **never delete anything you haven't measured first.** Start with the top-level damage report:

```bash
df -h
du -h -d 1 ~ 2>/dev/null | sort -hr | head -20
```

On my machine this immediately produced suspects:

```
257G    /Users/me
 87G    /Users/me/Library
 78G    /Users/me/Projects
 10G    /Users/me/.espressif
8.1G    /Users/me/.gemini
3.4G    /Users/me/go
2.2G    /Users/me/.rustup
2.0G    /Users/me/.gradle
1.9G    /Users/me/.cursor
```

87 GB in `~/Library`. Let's zoom in:

```bash
du -h -d 1 ~/Library 2>/dev/null | sort -hr | head -10
du -h -d 1 ~/Library/Caches 2>/dev/null | sort -hr | head -15
```

```
 29G    ~/Library/Application Support
 24G    ~/Library/Caches
 14G    ~/Library/Arduino15
 10G    ~/Library/Developer
```

**24 GB of caches.** Yarn alone was sitting on 5.1 GB. Google's cache folder had 4.3 GB. A disk imaging tool I used *once* had kept 4.1 GB of downloaded OS images as a souvenir.

## The usual suspects (a checklist)

After going through my whole disk, here's what actually eats space on a developer's Mac, roughly in order of guilt:

### 1. `~/Library/Caches` — the obvious one

Safe to clear almost entirely. Apps rebuild caches on next launch. The catch: it's not one folder, it's *hundreds* — one per app, including apps you deleted two years ago.

### 2. Package manager caches — the silent hoarders

Every ecosystem keeps its own stash, and none of them ever clean up after themselves:

```bash
du -sh ~/Library/Caches/Yarn ~/.npm/_cacache ~/Library/Caches/pip \
       ~/Library/Caches/Homebrew ~/.gradle/caches ~/go/pkg/mod \
       ~/Library/Caches/CocoaPods ~/.nuget/packages 2>/dev/null
```

My Go module cache was **3.2 GB** of packages for projects I'd finished months ago. All of this re-downloads on demand — it's pure cache.

Fun gotcha: the Go module cache ships with read-only permissions, so a naive `rm -rf` fails halfway through. You need `chmod -R u+w` first. Ask me how I know.

### 3. Xcode — a category of its own

If you do any iOS/macOS development:

```bash
du -h -d 1 ~/Library/Developer 2>/dev/null | sort -hr
```

- **DerivedData** — build intermediates, safe to nuke, rebuilds on next build
- **iOS DeviceSupport** — debug symbols for every iOS version of every device you've ever plugged in, 2–5 GB *each*
- **CoreSimulator** — old simulators easily hold 20–40 GB across Xcode versions
- **Archives** — every app you've ever shipped, forever

`xcrun simctl delete unavailable` alone freed several GB of orphaned simulators for me.

### 4. Build artifacts scattered across your projects

This was my biggest shock: **45 GB of build folders and 8 GB of `node_modules`** spread across `~/Projects`.

Finding them is trickier than it sounds, because the folder names are ambiguous. `node_modules` and `__pycache__` are unmistakable, but `build`, `dist`, `target`, `vendor`? Those could be anything — you can't just delete every folder named `build` on your disk.

The trick I landed on: **validate by marker files.** A folder named `target` is only a Rust build if `Cargo.toml` sits next to it. `build` is only sacrificeable if the parent has `build.gradle`, `CMakeLists.txt`, `package.json`, or `pubspec.yaml`. `vendor` counts only next to `composer.json` or `go.mod`. `bin`/`obj` only next to a `*.csproj`. Python's `venv` proves itself by containing `pyvenv.cfg`.

With that heuristic you can sweep your whole home directory safely:

```bash
# unambiguous ones are easy:
find ~ -type d \( -name node_modules -o -name __pycache__ -o -name .venv \) \
  -not -path "$HOME/Library/*" -prune -print 2>/dev/null
```

Everything restores with `npm install` / `cargo build` / `pip install` when you actually return to that project. Spoiler: you won't return to most of them.

### 5. The weird ones nobody talks about

- **iOS device backups**: `~/Library/Application Support/MobileSync/Backup` — old iPhone backups from that one time you used Finder sync. Often 10–50 GB.
- **Mail Downloads**: `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads` — attachments you viewed once, kept forever.
- **Electron app junk**: every Electron/Chromium app keeps `Cache`, `Code Cache`, `GPUCache`, `ShaderCache` and logs inside `~/Library/Application Support/<App>/`. Individually small, collectively gigabytes — Discord, Slack, Postman, Obsidian, all of them.
- **Old Downloads**: `find ~/Downloads -maxdepth 1 -mtime +30` — everything untouched for a month. For me that was 25 items including three copies of the same installer.

## Safety rules I follow

1. **Trash, not `rm`** — move things to the Trash first, delete permanently only after a week of nothing breaking.
2. **Never touch**: `~/Library/Keychains`, `Mail`, `Messages`, `Mobile Documents` (that's iCloud!), and on Apple Silicon leave `/System/Library/Caches` alone — macOS manages it.
3. **Close the heavy apps first** — clearing a cache out from under a running browser or IDE causes weirdness.
4. **Look before you delete.** Categories like "old downloads" contain surprises — mine had API keys (`AuthKey_*.p8`) I definitely still needed.

## The confession part

I did this cleanup manually with `du`, `find` and `rm` exactly once. It took an evening, I freed about 60 GB… and three weeks later the disk was filling up again, because caches do what caches do.

So — like every developer with a shell history full of `du -h -d 1` — I ended up building a small native macOS app that does this loop for me: scans all the locations above (plus auto-discovers caches of any app it finds), tags everything Safe / Caution / Risky, shows the actual file list behind every category with checkboxes, and defaults to moving things to the Trash. The marker-file validation for build folders came straight out of this experiment.

It's free, no subscriptions, signed and notarized, and I mostly built it for myself — but if your `df -h` looks like mine did, it might save you an evening: **[Again Cleaner](https://againcleaner.com)**. If you'd rather do it by hand, every command you need is in this post — that's genuinely how the app works under the hood.

Either way: go run `du -h -d 1 ~ | sort -hr | head -20` right now. I'll wait. The number next to `~/Library` is going to annoy you.

---

*What's the biggest space hog you've found on your machine? I'm collecting new categories — the weirdest one I've heard so far is 30 GB of Slack video call recordings nobody knew existed.*
