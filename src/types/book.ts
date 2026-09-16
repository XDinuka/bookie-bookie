export type Book = {
  id: string;
  isbn: string | null;
  title: string;
  author: string | null;
  coverUrl: string | null;
  addedAt: number;
};

export type NewBook = Omit<Book, 'id' | 'addedAt'>;
