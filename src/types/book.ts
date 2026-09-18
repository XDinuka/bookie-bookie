export type BookStatus = 'ready' | 'processing' | 'needs-review';

export type Book = {
  id: string;
  isbn: string | null;
  title: string;
  author: string | null;
  coverUrl: string | null;
  addedAt: number;
  status: BookStatus;
  /** Local photo URIs captured for this book, kept for OCR + manual review. */
  photoUris: string[];
  /** Raw combined OCR text, kept so the user can cross-check the guessed fields. */
  rawOcrText: string | null;
};

export type NewBook = Omit<Book, 'id' | 'addedAt' | 'status' | 'photoUris' | 'rawOcrText'> &
  Partial<Pick<Book, 'status' | 'photoUris' | 'rawOcrText'>>;
