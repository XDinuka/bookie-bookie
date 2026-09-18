import { isValidIsbn, normalizeIsbn } from '@/lib/isbn';

export type ParsedOcrFields = {
  isbn: string | null;
  title: string;
  author: string;
};

const ISBN_CANDIDATE = /(97[89][-\s]?\d[-\s]?\d{1,7}[-\s]?\d{1,7}[-\s]?\d|\d{9}[\dXx])/g;

function findIsbn(rawText: string): string | null {
  const candidates = rawText.match(ISBN_CANDIDATE) ?? [];
  for (const candidate of candidates) {
    const normalized = normalizeIsbn(candidate);
    if (isValidIsbn(normalized)) return normalized;
  }
  return null;
}

/**
 * Best-effort field extraction from raw multi-photo OCR text. There's no
 * layout information here, just line order and length, so this is meant as
 * a starting point for the user to correct on the review screen — not a
 * confident structured parse.
 */
export function parseOcrFields(rawText: string): ParsedOcrFields {
  const isbn = findIsbn(rawText);

  const lines = rawText
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length >= 2)
    // Drop lines that are mostly digits/punctuation (barcode numbers, page counts, prices).
    .filter((line) => {
      const letters = line.replace(/[^a-zA-Z඀-෿]/g, '');
      return letters.length >= Math.max(2, line.length * 0.4);
    });

  const sortedByLength = [...new Set(lines)].sort((a, b) => b.length - a.length);

  const title = sortedByLength[0] ?? '';
  const author = sortedByLength.find((line) => line !== title) ?? '';

  return { isbn, title, author };
}
