import { updateBook } from '@/lib/book-store';
import { isSriLankanIsbn, lookupIsbn } from '@/lib/isbn';
import { runOcr } from '@/lib/ocr';
import { parseOcrFields } from '@/lib/ocr-parse';

type Job = { bookId: string; photoUris: string[] };

const queue: Job[] = [];
let processing = false;

/** Fire-and-forget: the caller (the capture screen) moves on immediately. */
export function enqueueOcrJob(job: Job) {
  queue.push(job);
  void processQueue();
}

async function processQueue() {
  if (processing) return;
  processing = true;
  while (queue.length > 0) {
    const job = queue.shift()!;
    await processJob(job);
  }
  processing = false;
}

async function processJob(job: Job) {
  try {
    const texts = await Promise.all(job.photoUris.map((uri) => runOcr(uri).catch(() => '')));
    const rawOcrText = texts.filter(Boolean).join('\n\n');
    const { isbn, title, author } = parseOcrFields(rawOcrText);

    let finalTitle = title;
    let finalAuthor: string | null = author || null;
    let coverUrl: string | null = job.photoUris[0] ?? null;

    // Sri Lankan ISBNs (group 955) have no coverage in these catalogs, so
    // skip the round trip; still worth trying for any other ISBN we OCR'd.
    if (isbn && !isSriLankanIsbn(isbn)) {
      const apiResult = await lookupIsbn(isbn).catch(() => null);
      if (apiResult) {
        finalTitle = apiResult.title;
        finalAuthor = apiResult.author;
        coverUrl = apiResult.coverUrl ?? coverUrl;
      }
    }

    await updateBook(job.bookId, {
      isbn,
      title: finalTitle || 'Untitled — needs review',
      author: finalAuthor,
      coverUrl,
      rawOcrText,
      status: 'needs-review',
    });
  } catch (err) {
    // Never leave the record stuck on "Processing…" — surface the failure
    // as something the user can open and fix by hand instead.
    await updateBook(job.bookId, {
      title: "Couldn't read this book — needs review",
      rawOcrText: err instanceof Error ? err.message : String(err),
      status: 'needs-review',
    });
  }
}
