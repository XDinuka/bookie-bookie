import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

export type BookDraft = {
  isbn: string | null;
  title: string;
  author: string;
  coverUrl: string | null;
};

type BookConfirmCardProps = {
  draft: BookDraft;
  onChange: (patch: Partial<BookDraft>) => void;
  message: string;
  onCancel: () => void;
  onConfirm: () => void;
  confirmLabel?: string;
};

export function BookConfirmCard({
  draft,
  onChange,
  message,
  onCancel,
  onConfirm,
  confirmLabel = 'Add to Library',
}: BookConfirmCardProps) {
  const theme = useTheme();

  async function handleTakeCoverPhoto() {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchCameraAsync({
      allowsEditing: true,
      aspect: [2, 3],
      quality: 0.7,
    });
    if (result.canceled || !result.assets[0]) return;

    onChange({ coverUrl: result.assets[0].uri });
  }

  return (
    <ThemedView type="backgroundElement" style={styles.card}>
      {draft.coverUrl ? (
        <Image source={{ uri: draft.coverUrl }} style={styles.cover} contentFit="cover" />
      ) : (
        <View style={[styles.cover, styles.coverPlaceholder, { backgroundColor: theme.backgroundSelected }]} />
      )}
      <Pressable onPress={handleTakeCoverPhoto} style={({ pressed }) => pressed && styles.pressed}>
        <ThemedText type="linkPrimary">
          {draft.coverUrl ? 'Retake cover photo' : 'Take a photo of the cover'}
        </ThemedText>
      </Pressable>

      <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
        {message}
      </ThemedText>

      <TextInput
        value={draft.title}
        onChangeText={(title) => onChange({ title })}
        placeholder="Title"
        placeholderTextColor={theme.textSecondary}
        style={[styles.input, { color: theme.text, backgroundColor: theme.background }]}
      />
      <TextInput
        value={draft.author}
        onChangeText={(author) => onChange({ author })}
        placeholder="Author"
        placeholderTextColor={theme.textSecondary}
        style={[styles.input, { color: theme.text, backgroundColor: theme.background }]}
      />
      {draft.isbn ? (
        <ThemedText type="code" themeColor="textSecondary">
          ISBN {draft.isbn}
        </ThemedText>
      ) : null}

      <View style={styles.buttonRow}>
        <Pressable onPress={onCancel} style={({ pressed }) => [styles.button, pressed && styles.pressed]}>
          <ThemedText type="smallBold" themeColor="textSecondary">
            Cancel
          </ThemedText>
        </Pressable>
        <Pressable
          disabled={!draft.title.trim()}
          onPress={onConfirm}
          style={({ pressed }) => [
            styles.button,
            { backgroundColor: theme.backgroundSelected },
            (pressed || !draft.title.trim()) && styles.pressed,
          ]}>
          <ThemedText type="smallBold">{confirmLabel}</ThemedText>
        </Pressable>
      </View>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
  },
  cover: {
    width: 96,
    height: 144,
    borderRadius: Spacing.two,
  },
  coverPlaceholder: {
    borderStyle: 'dashed',
    borderWidth: 1,
    borderColor: 'rgba(128,128,128,0.4)',
  },
  input: {
    width: '100%',
    borderRadius: Spacing.two,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    fontSize: 16,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: Spacing.three,
    marginTop: Spacing.one,
  },
  button: {
    paddingHorizontal: Spacing.four,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.five,
  },
  centerText: {
    textAlign: 'center',
  },
  pressed: {
    opacity: 0.7,
  },
});
