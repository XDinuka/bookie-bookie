# Bookie Bookie — Project Context

A private, personal library catalog app for a predominantly Sri Lankan audience. Scan or photograph your physical books to build a digital catalog: title, author, ISBN, cover image. Local-only storage, no account, no backend.

This file is a working record of what's been built, why, and what's still unresolved — written for picking the project back up in a fresh session.

## Stack

- **Expo SDK 57** (React Native 0.86, React 19.2), managed workflow, Expo Router (file-based routing).
- `app.json`: `ios.bundleIdentifier` / `android.package` = `com.xdinuka.bookie-bookie` / `com.xdinuka.bookiebookie` (Android disallows hyphens, so it's the hyphen-stripped equivalent there).
- No backend. Everything persists locally via `@react-native-async-storage/async-storage`.
- **Important**: Expo has changed significantly across recent SDKs (see `AGENTS.md` at repo root) — always check installed package type definitions (`node_modules/*/build/*.d.ts`) rather than assume an API from training knowledge or older docs. `docs.expo.dev` is blocked by this sandbox's network egress proxy, so verification has to go through installed `.d.ts` files and web search snippets instead of the docs site directly.

## App structure (3 tabs + 1 detail screen)

Routes live under `src/app/(tabs)/` (a route group, doesn't affect URLs) plus a sibling `src/app/book/[id].tsx`. The root `src/app/_layout.tsx` is a `Stack` with two screens: `(tabs)` (headerShown: false) and `book/[id]` (pushes over the tab bar, standard Expo Router pattern for a detail screen that isn't itself a tab).

1. **Library** (`(tabs)/index.tsx`) — searchable list of all cataloged books. Shows a status badge per book: spinner + "Processing…", or a "Needs review" pill. Tapping a row opens the detail/review screen (`book/[id].tsx`). Delete via trash icon.
2. **Scan** (`(tabs)/explore.tsx`) — camera-only. Live barcode scanning (EAN-13/EAN-8) via `expo-camera`'s `CameraView`. On a scanned ISBN: checks for a duplicate already in the library, otherwise looks it up online (see ISBN lookup below), shows a confirm card (`BookConfirmCard`) to edit/confirm, then adds it. No manual text entry here — that's the whole point of this tab per explicit user request ("scan should only be using the camera").
3. **Add** (`(tabs)/add.tsx`) — everything that isn't pure barcode scanning, split into two modes via a toggle:
   - **Enter ISBN**: manual ISBN text entry + lookup, same confirm-card flow as Scan.
   - **Capture Photos**: the main path for books whose ISBN barcode doesn't have online metadata (see "Sri Lanka ISBN gap" below). Take several photos of a book (cover, spine, title page — whatever's needed) via `CameraView` + manual shutter (`takePictureAsync`), then tap Done. This immediately inserts a `processing`-status book record and queues a background OCR job, freeing the user to start capturing the next book right away.
4. **book/[id]** (`src/app/book/[id].tsx`) — review/edit screen. If the book is still `processing`, shows a spinner with no editable form. Once OCR finishes (`needs-review` or `ready`), shows the same `BookConfirmCard` pre-filled with best-guess fields, plus the raw OCR text for reference, plus a delete button.

`BookConfirmCard` (`src/components/book-confirm-card.tsx`) is shared between Scan and Add's manual-entry path: cover image (or a "take a photo of the cover" fallback using `expo-image-picker`'s `launchCameraAsync`), editable title/author fields, ISBN display, cancel/confirm buttons.

## Data model (`src/types/book.ts`, `src/lib/book-store.ts`)

```ts
type BookStatus = 'ready' | 'processing' | 'needs-review';
type Book = {
  id: string; isbn: string | null; title: string; author: string | null;
  coverUrl: string | null; addedAt: number; status: BookStatus;
  photoUris: string[]; rawOcrText: string | null;
};
```

Store is a hand-rolled module-level store (`useSyncExternalStore`-based), persisted to AsyncStorage as one JSON blob under key `bookie-bookie/books`. Key detail: the initial `AsyncStorage.getItem` load is **lazy**, kicked off from a `useEffect` (client-only) rather than at module import time — the app also builds via static web export (`expo export -p web`), which prerenders routes in Node with no `window`/storage; loading eagerly at module scope crashed that build (`window is not defined`). Fixed in commit `d1b49dd`/later.

`addPendingBook(photoUris)` inserts a placeholder (`status: 'processing'`, title "Processing…", cover = first photo) immediately so it's visible in the Library while OCR runs. `updateBook(id, patch)` is how the OCR queue and the review screen both apply results/edits.

## ISBN lookup (`src/lib/isbn.ts`)

Two free, no-key APIs tried in order:
1. **Open Library**: `https://openlibrary.org/api/books?bibkeys=ISBN:<isbn>&format=json&jscmd=data`
2. **Google Books** (fallback): `https://www.googleapis.com/books/v1/volumes?q=isbn:<isbn>`

Both wrapped with an 8s timeout (`AbortController`) — an earlier bug (commit `b3169e0`) had the Scan screen hang forever on "Looking up ISBN…" because `fetch()` had no timeout and no cancel button; fixed by adding both.

### The Sri Lanka ISBN gap

Since the audience is predominantly Sri Lankan: **neither Open Library nor Google Books has meaningful coverage of ISBN registration group 955 (Sri Lanka)**. Researched and confirmed this is a real, unsolved gap — the National Library of Sri Lanka (the issuing agency) has no public API or even a browsable list. This is *why* the photo-capture + OCR flow exists at all — it's not a nice-to-have, it's the primary path for this app's actual audience.

`isSriLankanIsbn(isbn)` in `isbn.ts` detects group 955 (`isbn.slice(3,6) === '955'` for ISBN-13, `isbn.slice(0,3)` for ISBN-10) so the OCR queue can skip the pointless API round-trip for those and go straight to the OCR guess — while still trying the API for any *other* ISBN the OCR happens to read off a cover (per explicit instruction: "we can also use the APIs just in case we find data... skip API calls for sri lankan isbns").

## OCR pipeline (background, on-device, Sinhala-capable)

Researched thoroughly before building (see conversation for full citations): **no free, on-device, drop-in OCR engine supports Sinhala**. Google ML Kit — no. Apple Vision framework — no. This is an acknowledged, still-unsolved gap in the field as of a July 2025 paper (arXiv:2507.18264) benchmarking six OCR engines on Sinhala/Tamil. Tesseract does have a trained Sinhala model (`sin.traineddata`) and was chosen (user's explicit choice over paid Cloud Vision or deferring OCR entirely) despite known weaker accuracy on decorative/stylized text like book covers.

**Architecture**: Tesseract runs via `tesseract.js` (the JS/WASM build) inside a **hidden `WebView`** (`react-native-webview`), since there's no maintained way to run native Tesseract inside a managed Expo app without ejecting.

- `src/lib/ocr.ts` — exports `OCR_WORKER_HTML` (a self-contained HTML page loading `tesseract.js` from jsdelivr CDN, creating a `Tesseract.createWorker(['sin','eng'])`, listening for `postMessage`/`message` events with `{id, imageDataUri}` jobs, replying via `window.ReactNativeWebView.postMessage`). Also exports `runOcr(imageUri)`, a promise-based API: reads the photo via `expo-file-system`'s modern `File` class (`new File(uri).base64()` — **not** the old `readAsStringAsync`, which no longer exists in this SDK's `expo-file-system`), builds a data URI, posts a job, resolves when the matching response arrives.
- `src/components/ocr-worker.tsx` — the `<WebView>` wrapper component; wires `onMessage`/`postMessage` to `ocr.ts`'s module-level registry.
- `src/lib/ocr-parse.ts` — `parseOcrFields(rawText)`: heuristic, not a real structured parse. Finds an ISBN via regex; guesses title = longest non-numeric line, author = second-longest. Explicitly a starting point for manual correction, not a confident extraction — matches the user's own stated expectation ("then user can manually check if anything needs correcting").
- `src/lib/ocr-queue.ts` — sequential in-memory job queue (`enqueueOcrJob({bookId, photoUris})`, fire-and-forget from the capture screen). For each queued book: runs OCR on all its photos, concatenates the text, parses fields, conditionally calls the ISBN APIs (skipping Sri Lankan ISBNs per above), then `updateBook(...)` with `status: 'needs-review'`. **Never leaves a record stuck on "Processing…"** — even an OCR failure gets caught and surfaced as a reviewable (if unhelpfully-titled) record rather than hanging forever, mirroring the earlier "stuck on Looking up ISBN" lesson.
- Caveat, disclosed to the user: `tesseract.js` is fetched from a CDN inside the WebView on first use (needs network that one time); real-world Sinhala OCR accuracy on stylized cover typography is **unverified** — this sandbox has no way to test it against an actual device/photo.

### `useOcrWorkerActive()` — why the WebView isn't always mounted

See "Open bug" below — as of the latest commit, `OcrWorker` is only mounted while a job is actually in flight (`ocr-queue.ts` exposes a subscribable `useOcrWorkerActive()` boolean), not permanently at the root. `ocr.ts`'s `unregisterOcrWorker()` resets `workerReady`/`workerInitError` on unmount so a later remount correctly waits for its own fresh "ready" signal.

## Other features

- **Cover photo capture fallback** (commit `cfe244c`): when online lookup finds no cover (common for Sri Lankan books), `BookConfirmCard` offers "take a photo of the cover" via `expo-image-picker`.
- Camera-only Scan tab; Add tab manual entry deliberately separated per explicit user instruction mid-session.

## Dependencies added beyond the starter template

All installed via `npx expo install <pkg>@<sdk-matched-version>` (checked against `node_modules/expo/**/bundledNativeModules.json` for the correct SDK57-aligned version each time — `npm view <pkg> versions` alone is misleading since some Expo packages have unrelated old version numbers from before they switched to SDK-aligned versioning):

- `expo-camera` (barcode scanning + manual photo capture)
- `expo-image-picker` (cover photo / launchCameraAsync)
- `@react-native-async-storage/async-storage` (persistence)
- `expo-file-system` (reading captured photos as base64 for OCR)
- `react-native-webview` (hosts the OCR worker)

`app.json` plugins added: `expo-camera` (camera permission text, mic disabled), `expo-image-picker` (camera permission text, photo library access disabled since we only take fresh photos).

## Cleanup done along the way

The original Expo starter template's demo content was removed as it was replaced: `WebBadge`, `HintRow`, `Collapsible`, `ExternalLink`, the non-splash half of `AnimatedIcon`, their associated image assets (react-logo, expo-badge, tutorial-web screenshots), and — later — the native tab bar icon assets (`tabIcons/`) once the tab bar implementation changed (see below). `AnimatedSplashOverlay` (the actual splash screen transition) was kept.

## Open bug: Android layout — app content confined to bottom half of screen

**Status: unresolved, three fix attempts so far, none confirmed working.** This is the most important open item.

**Symptom** (confirmed via user screenshot): on Android, roughly the top half of the screen is plain white (not our dark theme's black background — i.e., not our app's content at all), with only a floating Expo dev-tools gear icon on it. Our actual themed app content (Library screen: title, search box, tab bar, etc.) is confined to the bottom portion of the screen. Reported as affecting **all three tabs**, present from first app launch.

**Timeline**: first reported right after commit `7d6cfbc` ("Add multi-photo capture + background OCR, split Add/Scan tabs"), which was a large commit that simultaneously: (a) introduced the `(tabs)` route group + root `Stack` restructuring (needed so `book/[id]` can push over the tab bar), (b) mounted a permanent hidden `WebView` (`OcrWorker`) at the root, and (c) was still using `expo-router/unstable-native-tabs` at that point.

**Attempt 1** (commit `5ba13b5`): hypothesized `unstable-native-tabs` (explicitly labeled unstable) nested under a `Stack.Screen` was the cause — matches a real, documented category of GitHub issues. Replaced with `expo-router/ui`'s plain JS `Tabs`/`TabList`/`TabSlot` (reusing the web tab-bar implementation for all platforms). **User reported "still same" — no effect.**

**Attempt 2** (commit `cdaca8d`): re-diagnosed via more research — found current (2026), active, documented issues across `react-native-screens`/`react-navigation`/`react-native-safe-area-context` specifically about Android edge-to-edge enforcement breaking native `Screen`/`Fragment` sizing, matching the symptom closely. Called `enableScreens(false)` globally at the root to disable `react-native-screens`' native optimization app-wide (both the root `Stack` and the tabs' `TabSlot` render through it). **User reported "Still same" — no effect.**

**Attempt 3** (commit `f9d823b`, latest): reasoning that since two fixes targeting the entire navigation/screens layer had *zero* effect, the cause must be outside that layer entirely. The one major native component present, unchanged, across both failed attempts is `OcrWorker`'s permanently-mounted hidden `WebView`. Found a documented cross-framework (not RN-specific — reproduced in Kivy too) Android quirk: an `android.webkit.WebView`'s mere presence in the view hierarchy — even hidden/zero-sized — can put the Activity window into keyboard-resize (`adjustResize`-like) behavior regardless of manifest settings, squeezing all content into whatever space remains. Changed `OcrWorker` to only mount while `ocr-queue.ts` has an active job (`useOcrWorkerActive()`), rather than permanently. **Not yet verified by the user as of this writing.**

**If attempt 3 also fails**, the diagnostic split requested from the user was:
1. Does the bug still show at app launch, before ever touching Add → Capture Photos (i.e., before any OCR job has ever run, so the WebView has never mounted)?
2. If the bug is gone until a capture is queued, that confirms the WebView theory precisely.
3. If it's present at launch with zero OCR jobs ever run, the WebView theory is wrong too and the search needs to go elsewhere — candidates not yet investigated: `AnimatedSplashOverlay`'s stuck-transition edge cases, `SafeAreaProvider`/`initialWindowMetrics` injection issues specific to this Android version/device, or something in `app.json`'s Android config (e.g., `windowSoftInputMode`, which was never explicitly set and defaults to whatever Expo SDK 57 uses).

**Testing constraint throughout**: this sandbox has no Android device/emulator with a display — all three fixes were reasoned from documented library behavior, GitHub issues, and installed package source, not from actually reproducing the bug. All verification has been web static export (`npx expo export -p web` + serving + curling for text content / absence of runtime errors) and `tsc --noEmit`, which confirm the app *builds and type-checks* but say nothing about real Android rendering.

## Workflow notes for continuing this project

- User instruction (still standing as of this writing): **commit and push directly to `main`** for this repo, no feature branches, until told otherwise.
- Repo: `XDinuka/bookie-bookie`, no PR currently open.
- Always verify Expo API shapes against the actually-installed package's `.d.ts` files before writing code against them (`node_modules/<pkg>/build/*.d.ts` or `node_modules/<pkg>/build/**/*.d.ts`) — this SDK has genuinely different APIs than older training data would suggest (confirmed at least twice: `expo-file-system`'s `File` class vs. old `readAsStringAsync`; `expo-router`'s `Stack`/`NativeTabs`/`Tabs` API surface).
- `docs.expo.dev` and `openlibrary.org` are blocked by this sandbox's egress proxy (403 at the proxy level); `googleapis.com` for Google Books is reachable but this sandbox's shared quota is exhausted (429). None of this reflects real end-user behavior — it's sandbox-only.
- Before claiming a fix "works," remember it has only ever been verified via static web export + typecheck in this environment — real confirmation requires the user's Android device.
