export function normalizeIsbn(rawIsbn: string) {
  return rawIsbn.replace(/[^0-9Xx]/g, '').toUpperCase();
}

export function isValidIsbn(isbn: string) {
  return isbn.length === 10 || isbn.length === 13;
}

export type IsbnLookupResult = {
  title: string;
  author: string | null;
  coverUrl: string | null;
};

type OpenLibraryEntry = {
  title?: string;
  authors?: { name: string }[];
  cover?: { small?: string; medium?: string; large?: string };
};

async function lookupOpenLibrary(isbn: string): Promise<IsbnLookupResult | null> {
  const response = await fetch(
    `https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data`
  );
  if (!response.ok) return null;
  const data = (await response.json()) as Record<string, OpenLibraryEntry>;
  const entry = data[`ISBN:${isbn}`];
  if (!entry?.title) return null;

  return {
    title: entry.title,
    author: entry.authors?.map((author) => author.name).join(', ') ?? null,
    coverUrl: entry.cover?.medium ?? entry.cover?.large ?? entry.cover?.small ?? null,
  };
}

type GoogleBooksResponse = {
  items?: {
    volumeInfo?: {
      title?: string;
      authors?: string[];
      imageLinks?: { thumbnail?: string };
    };
  }[];
};

async function lookupGoogleBooks(isbn: string): Promise<IsbnLookupResult | null> {
  const response = await fetch(`https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}`);
  if (!response.ok) return null;
  const data = (await response.json()) as GoogleBooksResponse;
  const info = data.items?.[0]?.volumeInfo;
  if (!info?.title) return null;

  return {
    title: info.title,
    author: info.authors?.join(', ') ?? null,
    coverUrl: info.imageLinks?.thumbnail?.replace(/^http:/, 'https:') ?? null,
  };
}

export async function lookupIsbn(isbn: string): Promise<IsbnLookupResult | null> {
  const openLibraryResult = await lookupOpenLibrary(isbn).catch(() => null);
  if (openLibraryResult) return openLibraryResult;
  return lookupGoogleBooks(isbn).catch(() => null);
}
