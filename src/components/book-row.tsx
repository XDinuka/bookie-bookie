import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import type { Book } from '@/types/book';

type BookRowProps = {
  book: Book;
  onPress: () => void;
  onDelete: () => void;
};

export function BookRow({ book, onPress, onDelete }: BookRowProps) {
  const theme = useTheme();

  return (
    <Pressable onPress={onPress} style={({ pressed }) => pressed && styles.pressed}>
      <ThemedView type="backgroundElement" style={styles.row}>
        {book.coverUrl ? (
          <Image source={{ uri: book.coverUrl }} style={styles.cover} contentFit="cover" />
        ) : (
          <View style={[styles.cover, styles.coverPlaceholder, { backgroundColor: theme.backgroundSelected }]}>
            <SymbolView
              name={{ ios: 'book.closed', android: 'book_2', web: 'book' }}
              size={20}
              tintColor={theme.textSecondary}
            />
          </View>
        )}

        <View style={styles.details}>
          <ThemedText type="smallBold" numberOfLines={2}>
            {book.title}
          </ThemedText>
          {book.author ? (
            <ThemedText type="small" themeColor="textSecondary" numberOfLines={1}>
              {book.author}
            </ThemedText>
          ) : null}
          {book.isbn ? (
            <ThemedText type="code" themeColor="textSecondary">
              ISBN {book.isbn}
            </ThemedText>
          ) : null}
          {book.status === 'processing' ? (
            <View style={styles.statusRow}>
              <ActivityIndicator size="small" />
              <ThemedText type="small" themeColor="textSecondary">
                Processing…
              </ThemedText>
            </View>
          ) : book.status === 'needs-review' ? (
            <View style={[styles.statusPill, { backgroundColor: theme.backgroundSelected }]}>
              <ThemedText type="small" themeColor="text">
                Needs review
              </ThemedText>
            </View>
          ) : null}
        </View>

        <Pressable
          onPress={onDelete}
          hitSlop={12}
          style={({ pressed }) => [styles.deleteButton, pressed && styles.pressed]}>
          <SymbolView
            name={{ ios: 'trash', android: 'delete', web: 'delete' }}
            size={18}
            tintColor={theme.textSecondary}
          />
        </Pressable>
      </ThemedView>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: Spacing.three,
    padding: Spacing.three,
    borderRadius: Spacing.three,
    alignItems: 'center',
  },
  cover: {
    width: 48,
    height: 72,
    borderRadius: Spacing.one,
  },
  coverPlaceholder: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  details: {
    flex: 1,
    gap: Spacing.half,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one,
    marginTop: Spacing.half,
  },
  statusPill: {
    alignSelf: 'flex-start',
    paddingHorizontal: Spacing.two,
    paddingVertical: 2,
    borderRadius: Spacing.two,
    marginTop: Spacing.half,
  },
  deleteButton: {
    padding: Spacing.two,
  },
  pressed: {
    opacity: 0.6,
  },
});
