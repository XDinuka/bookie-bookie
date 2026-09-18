# Bookie Bookie

A private, personal library catalog app. Scan or photograph the books you own to build a digital catalog: title, author, ISBN, and cover image. Local-only — no account, no backend, no sync.

This is a fresh rebuild in **Flutter**. A prior attempt in Expo/React Native lives on the `approch-1-react-native` branch, abandoned after repeated native-layer instability (Android edge-to-edge rendering, `react-native-screens`, WebView side effects) ate too much time relative to progress on the actual app. See that branch's `CONTEXT.md` for the full writeup if useful background, but this rebuild is not bound by any of its architecture or decisions.

## Audience

Predominantly Sri Lankan. This matters functionally, not just cosmetically:

- **ISBN metadata lookups will fail for most Sri Lankan books.** Sri Lanka's ISBN registration group (955) has essentially no coverage in Open Library or Google Books — the two free, no-key APIs suitable for this kind of lookup. The National Library of Sri Lanka (the issuing agency) has no public API or browsable catalog either. This is a confirmed, structural gap, not a bug to work around — the app has to be designed assuming online lookup often won't have data.
- **Titles and author names are often in Sinhala script**, both for manual typing/display and for anything that tries to read text off a photographed cover. No free, on-device OCR engine currently supports Sinhala well (confirmed: Google ML Kit does not, Apple's Vision framework does not; Tesseract has a trained Sinhala model but weaker accuracy, especially on stylized cover typography rather than plain printed text).

## Core functionality

### Cataloging a book

Three ways to add a book, because no single one works for every book in this library:

1. **Scan the barcode.** Point the camera at a book's ISBN barcode (EAN-13/EAN-8). On a successful read: check if it's already cataloged; if not, look up the ISBN online (see below) to try to auto-fill title/author/cover; show a confirm/edit screen before saving.
2. **Type the ISBN manually.** Same lookup-and-confirm flow, for when a barcode won't scan or isn't present.
3. **Capture photos + extract in the background.** For books where the barcode lookup won't have data (the common case for this audience) — take a few photos of the book (cover, spine, title page, whatever's legible), then move on immediately to the next book. Extraction (OCR text recognition, best-guess title/author/ISBN) happens in the background, asynchronously, so cataloging a stack of books isn't blocked waiting on any single one. Once extraction finishes, the book shows up in the catalog flagged for review so the user can correct whatever the automated guess got wrong.

### Online ISBN lookup

Two free, no-key APIs, tried in order:

1. Open Library: `https://openlibrary.org/api/books?bibkeys=ISBN:<isbn>&format=json&jscmd=data`
2. Google Books (fallback): `https://www.googleapis.com/books/v1/volumes?q=isbn:<isbn>`

Both need a request timeout and a way to cancel/bail out — a hung lookup should never leave the user stuck on a loading screen with no way out.

Sri Lankan ISBNs (group 955 — detectable from the ISBN itself: digits 4–6 of an ISBN-13, or the first 3 digits of an ISBN-10) should skip this lookup entirely rather than waste a round trip on a call known to return nothing.

### Cover images

When online lookup doesn't return a cover (the common case here), let the user take a photo of the actual physical cover instead of leaving the entry with no image.

### Review and correction

Since OCR-extracted data is a best guess, not a confident structured parse, every catalog entry needs to be easy to open and correct — title, author, ISBN, and cover should all be editable after the fact, not just at creation time.

### Search and management

Search/filter the catalog by title, author, or ISBN. Delete entries. That's the extent of library management needed — no collections, tags, ratings, or lending tracker unless asked for later.

### Storage

Local device storage only. No backend, no account, no cross-device sync. The catalog is private to the device it's built on.

## Explicitly out of scope for now

Anything not listed above — collections/shelves, export/backup, multi-device sync, social features, reading progress — is not part of the initial build. Don't build ahead of what's asked.

## Development workflow

**Commit and push directly to `main`.** No feature branches, until the first release ships — at which point branch/PR discipline should be revisited. This was an explicit standing instruction from the project owner for this repo.
