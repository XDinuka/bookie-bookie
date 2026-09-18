import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { BookConfirmCard, type BookDraft } from '@/components/book-confirm-card';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { MaxContentWidth, Spacing } from '@/constants/theme';
import { removeBook, updateBook, useBook } from '@/lib/book-store';

export default function BookDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const book = useBook(id);
  const [draft, setDraft] = useState<BookDraft | null>(null);

  useEffect(() => {
    if (book && book.status !== 'processing' && !draft) {
      setDraft({ isbn: book.isbn, title: book.title, author: book.author ?? '', coverUrl: book.coverUrl });
    }
  }, [book, draft]);

  if (!book) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  const bookId = book.id;

  async function handleSave() {
    if (!draft || !draft.title.trim()) return;
    await updateBook(bookId, {
      isbn: draft.isbn,
      title: draft.title.trim(),
      author: draft.author.trim() || null,
      coverUrl: draft.coverUrl,
      status: 'ready',
    });
    router.back();
  }

  async function handleDelete() {
    await removeBook(bookId);
    router.back();
  }

  return (
    <ScrollView contentContainerStyle={styles.scrollContent}>
      <View style={styles.inner}>
        {book.status === 'processing' ? (
          <ThemedView type="backgroundElement" style={styles.processingCard}>
            <ActivityIndicator />
            <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
              Still extracting details from your photos in the background — check back shortly.
            </ThemedText>
          </ThemedView>
        ) : draft ? (
          <>
            <BookConfirmCard
              draft={draft}
              onChange={(patch) => setDraft((current) => (current ? { ...current, ...patch } : current))}
              message={
                book.status === 'needs-review'
                  ? "Extracted automatically — double-check title, author, and ISBN."
                  : 'Edit details as needed.'
              }
              onCancel={() => router.back()}
              onConfirm={handleSave}
              confirmLabel="Save"
            />
            {book.rawOcrText ? (
              <ThemedView type="backgroundElement" style={styles.rawTextCard}>
                <ThemedText type="smallBold">Raw extracted text</ThemedText>
                <ThemedText type="small" themeColor="textSecondary">
                  {book.rawOcrText}
                </ThemedText>
              </ThemedView>
            ) : null}
          </>
        ) : null}

        <Pressable
          onPress={handleDelete}
          style={({ pressed }) => [styles.deleteButton, pressed && styles.pressed]}>
          <ThemedText type="smallBold" themeColor="textSecondary">
            Delete this book
          </ThemedText>
        </Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scrollContent: {
    alignItems: 'center',
    paddingVertical: Spacing.six,
  },
  inner: {
    width: '100%',
    maxWidth: MaxContentWidth,
    paddingHorizontal: Spacing.four,
    gap: Spacing.four,
  },
  processingCard: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
  },
  rawTextCard: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    gap: Spacing.two,
  },
  deleteButton: {
    alignSelf: 'center',
    paddingVertical: Spacing.two,
    paddingHorizontal: Spacing.four,
  },
  centerText: {
    textAlign: 'center',
  },
  pressed: {
    opacity: 0.7,
  },
});
