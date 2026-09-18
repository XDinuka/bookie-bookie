import { CameraView, useCameraPermissions } from 'expo-camera';
import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import { useRef, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BookConfirmCard, type BookDraft } from '@/components/book-confirm-card';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { MaxContentWidth, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { addBook, addPendingBook, findBookByIsbn } from '@/lib/book-store';
import { isValidIsbn, lookupIsbn, normalizeIsbn } from '@/lib/isbn';
import { enqueueOcrJob } from '@/lib/ocr-queue';

type Mode = 'capture' | 'manual';

type ManualStage =
  | { kind: 'idle' }
  | { kind: 'looking-up'; isbn: string }
  | { kind: 'duplicate'; isbn: string; title: string }
  | { kind: 'confirm'; draft: BookDraft; foundOnline: boolean }
  | { kind: 'added'; title: string };

export default function AddScreen() {
  const [mode, setMode] = useState<Mode>('capture');

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <ThemedText type="subtitle">Add a Book</ThemedText>
        <View style={styles.modeToggle}>
          <ModeButton label="Capture Photos" active={mode === 'capture'} onPress={() => setMode('capture')} />
          <ModeButton label="Enter ISBN" active={mode === 'manual'} onPress={() => setMode('manual')} />
        </View>
      </View>
      {mode === 'capture' ? <CaptureMode /> : <ManualMode />}
    </View>
  );
}

function ModeButton({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  const theme = useTheme();
  return (
    <Pressable
      onPress={onPress}
      style={[styles.modeButton, { backgroundColor: active ? theme.backgroundSelected : theme.backgroundElement }]}>
      <ThemedText type="smallBold" themeColor={active ? 'text' : 'textSecondary'}>
        {label}
      </ThemedText>
    </Pressable>
  );
}

function CaptureMode() {
  const theme = useTheme();
  const safeAreaInsets = useSafeAreaInsets();
  const [permission, requestPermission] = useCameraPermissions();
  const [photos, setPhotos] = useState<string[]>([]);
  const [queuedTitle, setQueuedTitle] = useState<string | null>(null);
  const cameraRef = useRef<CameraView>(null);

  const contentPlatformStyle = Platform.select({
    android: {
      paddingTop: safeAreaInsets.top,
      paddingLeft: safeAreaInsets.left,
      paddingRight: safeAreaInsets.right,
    },
    web: { paddingTop: Spacing.three },
  });

  async function handleShutter() {
    const picture = await cameraRef.current?.takePictureAsync({ quality: 0.7 });
    if (picture?.uri) setPhotos((current) => [...current, picture.uri]);
  }

  function handleRemovePhoto(uri: string) {
    setPhotos((current) => current.filter((photoUri) => photoUri !== uri));
  }

  async function handleFinish() {
    if (photos.length === 0) return;
    const pending = await addPendingBook(photos);
    enqueueOcrJob({ bookId: pending.id, photoUris: photos });
    setPhotos([]);
    setQueuedTitle('Queued for background OCR — check the Library tab shortly.');
    setTimeout(() => setQueuedTitle(null), 2500);
  }

  return (
    <View style={[styles.inner, contentPlatformStyle]}>
      <ThemedText type="small" themeColor="textSecondary">
        For books without usable barcode data: take a few photos (cover, spine, title page — whatever has the
        title, author, or ISBN), then finish. Extraction happens in the background so you can move straight on
        to the next book.
      </ThemedText>

      {!permission ? (
        <ActivityIndicator />
      ) : !permission.granted ? (
        <ThemedView type="backgroundElement" style={styles.messageCard}>
          <ThemedText type="small" style={styles.centerText}>
            Camera access is needed to capture book photos.
          </ThemedText>
          <Pressable
            onPress={requestPermission}
            style={({ pressed }) => [
              styles.actionButton,
              { backgroundColor: theme.backgroundSelected },
              pressed && styles.pressed,
            ]}>
            <ThemedText type="smallBold">Grant camera access</ThemedText>
          </Pressable>
        </ThemedView>
      ) : (
        <>
          <View style={styles.cameraCard}>
            <CameraView ref={cameraRef} style={styles.camera} facing="back" />
            <Pressable
              onPress={handleShutter}
              style={({ pressed }) => [styles.shutterButton, pressed && styles.pressed]}>
              <View style={[styles.shutterInner, { backgroundColor: theme.text }]} />
            </Pressable>
          </View>

          {photos.length > 0 ? (
            <ScrollView horizontal contentContainerStyle={styles.thumbnailRow}>
              {photos.map((uri) => (
                <View key={uri} style={styles.thumbnailWrapper}>
                  <Image source={{ uri }} style={styles.thumbnail} contentFit="cover" />
                  <Pressable
                    onPress={() => handleRemovePhoto(uri)}
                    style={[styles.thumbnailRemove, { backgroundColor: theme.background }]}>
                    <SymbolView
                      name={{ ios: 'xmark', android: 'close', web: 'close' }}
                      size={12}
                      tintColor={theme.text}
                    />
                  </Pressable>
                </View>
              ))}
            </ScrollView>
          ) : null}

          <Pressable
            disabled={photos.length === 0}
            onPress={handleFinish}
            style={({ pressed }) => [
              styles.actionButton,
              styles.finishButton,
              { backgroundColor: theme.backgroundSelected },
              (pressed || photos.length === 0) && styles.pressed,
            ]}>
            <ThemedText type="smallBold">
              {photos.length === 0 ? 'Take a photo to continue' : `Done — process ${photos.length} photo${photos.length === 1 ? '' : 's'}`}
            </ThemedText>
          </Pressable>

          {queuedTitle ? (
            <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
              {queuedTitle}
            </ThemedText>
          ) : null}
        </>
      )}
    </View>
  );
}

function ManualMode() {
  const theme = useTheme();
  const [isbnInput, setIsbnInput] = useState('');
  const [stage, setStage] = useState<ManualStage>({ kind: 'idle' });

  async function handleLookup() {
    const isbn = normalizeIsbn(isbnInput);
    if (!isValidIsbn(isbn)) return;

    const existing = findBookByIsbn(isbn);
    if (existing) {
      setStage({ kind: 'duplicate', isbn, title: existing.title });
      return;
    }

    setStage({ kind: 'looking-up', isbn });
    const result = await lookupIsbn(isbn);
    setStage({
      kind: 'confirm',
      draft: {
        isbn,
        title: result?.title ?? '',
        author: result?.author ?? '',
        coverUrl: result?.coverUrl ?? null,
      },
      foundOnline: result != null,
    });
  }

  function reset() {
    setIsbnInput('');
    setStage({ kind: 'idle' });
  }

  async function handleAdd(draft: BookDraft) {
    if (!draft.title.trim()) return;
    await addBook({
      isbn: draft.isbn,
      title: draft.title.trim(),
      author: draft.author.trim() || null,
      coverUrl: draft.coverUrl,
    });
    setStage({ kind: 'added', title: draft.title.trim() });
    setTimeout(reset, 1200);
  }

  return (
    <View style={styles.inner}>
      {stage.kind === 'idle' ? (
        <View style={styles.manualRow}>
          <TextInput
            value={isbnInput}
            onChangeText={setIsbnInput}
            placeholder="e.g. 9780140449136"
            placeholderTextColor={theme.textSecondary}
            keyboardType="number-pad"
            style={[styles.manualInput, { color: theme.text, backgroundColor: theme.backgroundElement }]}
          />
          <Pressable
            disabled={!isValidIsbn(normalizeIsbn(isbnInput))}
            onPress={handleLookup}
            style={({ pressed }) => [
              styles.actionButton,
              { backgroundColor: theme.backgroundSelected },
              (pressed || !isValidIsbn(normalizeIsbn(isbnInput))) && styles.pressed,
            ]}>
            <ThemedText type="smallBold">Look up</ThemedText>
          </Pressable>
        </View>
      ) : stage.kind === 'looking-up' ? (
        <ThemedView type="backgroundElement" style={styles.messageCard}>
          <ActivityIndicator />
          <ThemedText type="small" themeColor="textSecondary">
            Looking up ISBN {stage.isbn}…
          </ThemedText>
        </ThemedView>
      ) : stage.kind === 'duplicate' ? (
        <ThemedView type="backgroundElement" style={styles.messageCard}>
          <ThemedText type="smallBold" style={styles.centerText}>
            &ldquo;{stage.title}&rdquo; is already in your library
          </ThemedText>
          <Pressable
            onPress={reset}
            style={({ pressed }) => [
              styles.actionButton,
              { backgroundColor: theme.backgroundSelected },
              pressed && styles.pressed,
            ]}>
            <ThemedText type="smallBold">Try another</ThemedText>
          </Pressable>
        </ThemedView>
      ) : stage.kind === 'confirm' ? (
        <BookConfirmCard
          draft={stage.draft}
          onChange={(patch) =>
            setStage((current) =>
              current.kind === 'confirm' ? { ...current, draft: { ...current.draft, ...patch } } : current
            )
          }
          message={
            stage.foundOnline
              ? 'Found online — edit details if needed.'
              : "Couldn't find this ISBN online. Enter the details manually."
          }
          onCancel={reset}
          onConfirm={() => handleAdd(stage.draft)}
        />
      ) : stage.kind === 'added' ? (
        <ThemedView type="backgroundElement" style={styles.messageCard}>
          <ThemedText type="smallBold">Added &ldquo;{stage.title}&rdquo; to your library</ThemedText>
        </ThemedView>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    alignItems: 'center',
  },
  header: {
    width: '100%',
    maxWidth: MaxContentWidth,
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.six,
    gap: Spacing.three,
  },
  modeToggle: {
    flexDirection: 'row',
    gap: Spacing.two,
  },
  modeButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.two,
    borderRadius: Spacing.three,
  },
  inner: {
    flex: 1,
    width: '100%',
    maxWidth: MaxContentWidth,
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.three,
    gap: Spacing.three,
  },
  cameraCard: {
    alignItems: 'center',
    gap: Spacing.three,
  },
  camera: {
    width: '100%',
    aspectRatio: 4 / 3,
    borderRadius: Spacing.three,
    overflow: 'hidden',
  },
  shutterButton: {
    width: 64,
    height: 64,
    borderRadius: 32,
    borderWidth: 3,
    borderColor: 'rgba(128,128,128,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  shutterInner: {
    width: 52,
    height: 52,
    borderRadius: 26,
  },
  thumbnailRow: {
    gap: Spacing.two,
  },
  thumbnailWrapper: {
    position: 'relative',
  },
  thumbnail: {
    width: 64,
    height: 64,
    borderRadius: Spacing.two,
  },
  thumbnailRemove: {
    position: 'absolute',
    top: -6,
    right: -6,
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  finishButton: {
    alignSelf: 'stretch',
    alignItems: 'center',
  },
  messageCard: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
  },
  actionButton: {
    paddingHorizontal: Spacing.four,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.three,
  },
  manualRow: {
    flexDirection: 'row',
    gap: Spacing.two,
  },
  manualInput: {
    flex: 1,
    borderRadius: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    fontSize: 16,
  },
  centerText: {
    textAlign: 'center',
  },
  pressed: {
    opacity: 0.7,
  },
});
