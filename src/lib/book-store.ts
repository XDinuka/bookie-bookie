import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useSyncExternalStore } from 'react';

import type { Book, NewBook } from '@/types/book';

const STORAGE_KEY = 'bookie-bookie/books';

let books: Book[] = [];
let loaded = false;
let loadPromise: Promise<void> | null = null;
const listeners = new Set<() => void>();

function notify() {
  for (const listener of listeners) listener();
}

function persist() {
  return AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(books));
}

// Started lazily (from a client-only effect or a mutation call) rather than at
// module scope, since this module also loads during static web prerendering,
// where there is no `window`/storage to read from.
function ensureLoaded(): Promise<void> {
  if (!loadPromise) {
    loadPromise = AsyncStorage.getItem(STORAGE_KEY).then((raw) => {
      books = raw ? (JSON.parse(raw) as Book[]) : [];
      loaded = true;
      notify();
    });
  }
  return loadPromise;
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useBooks() {
  useEffect(() => {
    ensureLoaded();
  }, []);
  return useSyncExternalStore(subscribe, () => books);
}

export function useBooksLoaded() {
  useEffect(() => {
    ensureLoaded();
  }, []);
  return useSyncExternalStore(subscribe, () => loaded);
}

export function findBookByIsbn(isbn: string) {
  return books.find((book) => book.isbn === isbn) ?? null;
}

export async function addBook(newBook: NewBook) {
  await ensureLoaded();
  const book: Book = {
    ...newBook,
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    addedAt: Date.now(),
  };
  books = [book, ...books];
  notify();
  await persist();
  return book;
}

export async function removeBook(id: string) {
  await ensureLoaded();
  books = books.filter((book) => book.id !== id);
  notify();
  await persist();
}
