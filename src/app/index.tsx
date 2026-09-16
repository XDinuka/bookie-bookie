import { useMemo, useState } from 'react';
import { FlatList, Platform, StyleSheet, TextInput } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BookRow } from '@/components/book-row';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { removeBook, useBooks, useBooksLoaded } from '@/lib/book-store';
import type { Book } from '@/types/book';

export default function LibraryScreen() {
  const books = useBooks();
  const loaded = useBooksLoaded();
  const theme = useTheme();
  const safeAreaInsets = useSafeAreaInsets();
  const [query, setQuery] = useState('');

  const insets = {
    ...safeAreaInsets,
    bottom: safeAreaInsets.bottom + BottomTabInset + Spacing.three,
  };

  const contentPlatformStyle = Platform.select({
    android: {
      paddingTop: insets.top,
      paddingLeft: insets.left,
      paddingRight: insets.right,
      paddingBottom: insets.bottom,
    },
    web: {
      paddingTop: Spacing.six,
      paddingBottom: Spacing.four,
    },
  });

  const filteredBooks = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    if (!normalizedQuery) return books;
    return books.filter((book) =>
      [book.title, book.author, book.isbn]
        .filter(Boolean)
        .some((field) => field!.toLowerCase().includes(normalizedQuery))
    );
  }, [books, query]);

  const renderEmptyState = () => {
    if (!loaded) return null;
    if (books.length === 0) {
      return (
        <ThemedView type="backgroundElement" style={styles.emptyState}>
          <ThemedText type="smallBold">Your library is empty</ThemedText>
          <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
            Head to the Scan tab and scan a book&apos;s barcode to add it here.
          </ThemedText>
        </ThemedView>
      );
    }
    return (
      <ThemedView type="backgroundElement" style={styles.emptyState}>
        <ThemedText type="small" themeColor="textSecondary">
          No books match &ldquo;{query}&rdquo;
        </ThemedText>
      </ThemedView>
    );
  };

  return (
    <FlatList<Book>
      style={[styles.list, { backgroundColor: theme.background }]}
      contentInset={insets}
      contentContainerStyle={[styles.contentContainer, contentPlatformStyle]}
      data={filteredBooks}
      keyExtractor={(book) => book.id}
      ListHeaderComponent={
        <ThemedView style={styles.header}>
          <ThemedText type="subtitle">My Library</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            {books.length} {books.length === 1 ? 'book' : 'books'} cataloged
          </ThemedText>
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search by title, author, or ISBN"
            placeholderTextColor={theme.textSecondary}
            style={[
              styles.searchInput,
              { color: theme.text, backgroundColor: theme.backgroundElement },
            ]}
          />
        </ThemedView>
      }
      renderItem={({ item }) => (
        <BookRow book={item} onDelete={() => removeBook(item.id)} />
      )}
      ItemSeparatorComponent={() => <ThemedView style={styles.separator} />}
      ListEmptyComponent={renderEmptyState}
    />
  );
}

const styles = StyleSheet.create({
  list: {
    flex: 1,
  },
  contentContainer: {
    paddingHorizontal: Spacing.four,
    maxWidth: MaxContentWidth,
    width: '100%',
    alignSelf: 'center',
    flexGrow: 1,
  },
  header: {
    gap: Spacing.two,
    paddingBottom: Spacing.four,
  },
  searchInput: {
    marginTop: Spacing.two,
    borderRadius: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    fontSize: 16,
  },
  separator: {
    height: Spacing.two,
  },
  emptyState: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.one,
  },
  centerText: {
    textAlign: 'center',
  },
});
