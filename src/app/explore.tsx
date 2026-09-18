import { CameraView, useCameraPermissions, type BarcodeScanningResult } from 'expo-camera';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { useRef, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { addBook, findBookByIsbn } from '@/lib/book-store';
import { isValidIsbn, lookupIsbn, normalizeIsbn } from '@/lib/isbn';

type Draft = {
  isbn: string;
  title: string;
  author: string;
  coverUrl: string | null;
  foundOnline: boolean;
};

type Stage =
  | { kind: 'scanning' }
  | { kind: 'looking-up'; isbn: string }
  | { kind: 'duplicate'; isbn: string; title: string }
  | { kind: 'confirm' }
  | { kind: 'added'; title: string };

export default function ScanScreen() {
  const theme = useTheme();
  const safeAreaInsets = useSafeAreaInsets();
  const [permission, requestPermission] = useCameraPermissions();
  const [stage, setStage] = useState<Stage>({ kind: 'scanning' });
  const [draft, setDraft] = useState<Draft | null>(null);
  const [manualIsbn, setManualIsbn] = useState('');
  const processingRef = useRef(false);
  const requestIdRef = useRef(0);

  const insets = {
    ...safeAreaInsets,
    bottom: safeAreaInsets.bottom + BottomTabInset + Spacing.three,
  };
  const contentPlatformStyle = Platform.select({
    android: { paddingTop: insets.top, paddingLeft: insets.left, paddingRight: insets.right },
    web: { paddingTop: Spacing.six },
  });

  function resetScan() {
    requestIdRef.current += 1; // invalidate any in-flight lookup
    processingRef.current = false;
    setDraft(null);
    setManualIsbn('');
    setStage({ kind: 'scanning' });
  }

  async function handleIsbnDetected(rawIsbn: string) {
    if (processingRef.current) return;
    const isbn = normalizeIsbn(rawIsbn);
    if (!isValidIsbn(isbn)) return;

    processingRef.current = true;
    const requestId = requestIdRef.current;

    const existing = findBookByIsbn(isbn);
    if (existing) {
      setStage({ kind: 'duplicate', isbn, title: existing.title });
      return;
    }

    setStage({ kind: 'looking-up', isbn });
    const result = await lookupIsbn(isbn);
    if (requestIdRef.current !== requestId) return; // cancelled while looking up

    setDraft({
      isbn,
      title: result?.title ?? '',
      author: result?.author ?? '',
      coverUrl: result?.coverUrl ?? null,
      foundOnline: result != null,
    });
    setStage({ kind: 'confirm' });
  }

  function handleBarcodeScanned(result: BarcodeScanningResult) {
    if (stage.kind !== 'scanning') return;
    handleIsbnDetected(result.data);
  }

  async function handleTakeCoverPhoto() {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) return;

    const result = await ImagePicker.launchCameraAsync({
      allowsEditing: true,
      aspect: [2, 3],
      quality: 0.7,
    });
    if (result.canceled || !result.assets[0]) return;

    setDraft((current) => (current ? { ...current, coverUrl: result.assets[0].uri } : current));
  }

  async function handleAdd() {
    if (!draft || !draft.title.trim()) return;
    await addBook({
      isbn: draft.isbn,
      title: draft.title.trim(),
      author: draft.author.trim() || null,
      coverUrl: draft.coverUrl,
    });
    setStage({ kind: 'added', title: draft.title.trim() });
    setTimeout(resetScan, 1200);
  }

  const manualEntry = (
    <View style={styles.manualRow}>
      <ThemedText type="small" themeColor="textSecondary">
        Or enter the ISBN manually
      </ThemedText>
      <View style={styles.manualInputRow}>
        <TextInput
          value={manualIsbn}
          onChangeText={setManualIsbn}
          placeholder="e.g. 9780140449136"
          placeholderTextColor={theme.textSecondary}
          keyboardType="number-pad"
          style={[
            styles.manualInput,
            { color: theme.text, backgroundColor: theme.backgroundElement },
          ]}
        />
        <Pressable
          disabled={!isValidIsbn(normalizeIsbn(manualIsbn))}
          onPress={() => handleIsbnDetected(manualIsbn)}
          style={({ pressed }) => [
            styles.lookupButton,
            { backgroundColor: theme.backgroundSelected },
            (pressed || !isValidIsbn(normalizeIsbn(manualIsbn))) && styles.pressed,
          ]}>
          <ThemedText type="smallBold">Look up</ThemedText>
        </Pressable>
      </View>
    </View>
  );

  return (
    <View
      style={[styles.container, { backgroundColor: theme.background }, contentPlatformStyle]}>
      <View style={styles.inner}>
        <ThemedText type="subtitle">Scan a Book</ThemedText>

        {!permission ? (
          <ActivityIndicator />
        ) : !permission.granted ? (
          <ThemedView type="backgroundElement" style={styles.permissionCard}>
            <ThemedText type="small" style={styles.centerText}>
              Camera access is needed to scan a book&apos;s barcode.
            </ThemedText>
            <Pressable
              onPress={requestPermission}
              style={({ pressed }) => [
                styles.lookupButton,
                { backgroundColor: theme.backgroundSelected },
                pressed && styles.pressed,
              ]}>
              <ThemedText type="smallBold">Grant camera access</ThemedText>
            </Pressable>
          </ThemedView>
        ) : stage.kind === 'scanning' ? (
          <View style={styles.cameraCard}>
            <CameraView
              style={styles.camera}
              facing="back"
              barcodeScannerSettings={{ barcodeTypes: ['ean13', 'ean8'] }}
              onBarcodeScanned={handleBarcodeScanned}
            />
            <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
              Point the camera at the book&apos;s barcode (usually on the back cover).
            </ThemedText>
          </View>
        ) : stage.kind === 'looking-up' ? (
          <ThemedView type="backgroundElement" style={styles.permissionCard}>
            <ActivityIndicator />
            <ThemedText type="small" themeColor="textSecondary">
              Looking up ISBN {stage.isbn}…
            </ThemedText>
            <Pressable
              onPress={resetScan}
              style={({ pressed }) => [styles.confirmButton, pressed && styles.pressed]}>
              <ThemedText type="smallBold" themeColor="textSecondary">
                Cancel
              </ThemedText>
            </Pressable>
          </ThemedView>
        ) : stage.kind === 'duplicate' ? (
          <ThemedView type="backgroundElement" style={styles.permissionCard}>
            <ThemedText type="smallBold" style={styles.centerText}>
              &ldquo;{stage.title}&rdquo; is already in your library
            </ThemedText>
            <ThemedText type="code" themeColor="textSecondary">
              ISBN {stage.isbn}
            </ThemedText>
            <Pressable
              onPress={resetScan}
              style={({ pressed }) => [
                styles.lookupButton,
                { backgroundColor: theme.backgroundSelected },
                pressed && styles.pressed,
              ]}>
              <ThemedText type="smallBold">Scan another</ThemedText>
            </Pressable>
          </ThemedView>
        ) : stage.kind === 'confirm' && draft ? (
          <ThemedView type="backgroundElement" style={styles.confirmCard}>
            {draft.coverUrl ? (
              <Image source={{ uri: draft.coverUrl }} style={styles.confirmCover} contentFit="cover" />
            ) : (
              <View style={[styles.confirmCover, styles.coverPlaceholder, { backgroundColor: theme.backgroundSelected }]} />
            )}
            <Pressable
              onPress={handleTakeCoverPhoto}
              style={({ pressed }) => pressed && styles.pressed}>
              <ThemedText type="linkPrimary">
                {draft.coverUrl ? 'Retake cover photo' : 'Take a photo of the cover'}
              </ThemedText>
            </Pressable>
            <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
              {draft.foundOnline
                ? 'Found online — edit details if needed.'
                : "Couldn't find this ISBN online. Enter the details manually."}
            </ThemedText>
            <TextInput
              value={draft.title}
              onChangeText={(title) => setDraft((current) => (current ? { ...current, title } : current))}
              placeholder="Title"
              placeholderTextColor={theme.textSecondary}
              style={[styles.confirmInput, { color: theme.text, backgroundColor: theme.background }]}
            />
            <TextInput
              value={draft.author}
              onChangeText={(author) => setDraft((current) => (current ? { ...current, author } : current))}
              placeholder="Author"
              placeholderTextColor={theme.textSecondary}
              style={[styles.confirmInput, { color: theme.text, backgroundColor: theme.background }]}
            />
            <ThemedText type="code" themeColor="textSecondary">
              ISBN {draft.isbn}
            </ThemedText>
            <View style={styles.confirmButtonRow}>
              <Pressable
                onPress={resetScan}
                style={({ pressed }) => [styles.confirmButton, pressed && styles.pressed]}>
                <ThemedText type="smallBold" themeColor="textSecondary">
                  Cancel
                </ThemedText>
              </Pressable>
              <Pressable
                disabled={!draft.title.trim()}
                onPress={handleAdd}
                style={({ pressed }) => [
                  styles.confirmButton,
                  styles.addButton,
                  { backgroundColor: theme.backgroundSelected },
                  (pressed || !draft.title.trim()) && styles.pressed,
                ]}>
                <ThemedText type="smallBold">Add to Library</ThemedText>
              </Pressable>
            </View>
          </ThemedView>
        ) : stage.kind === 'added' ? (
          <ThemedView type="backgroundElement" style={styles.permissionCard}>
            <ThemedText type="smallBold">Added &ldquo;{stage.title}&rdquo; to your library</ThemedText>
          </ThemedView>
        ) : null}

        {stage.kind === 'scanning' || !permission?.granted ? manualEntry : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
  },
  inner: {
    flex: 1,
    width: '100%',
    maxWidth: MaxContentWidth,
    paddingHorizontal: Spacing.four,
    gap: Spacing.four,
  },
  cameraCard: {
    gap: Spacing.three,
  },
  camera: {
    width: '100%',
    aspectRatio: 4 / 3,
    borderRadius: Spacing.three,
    overflow: 'hidden',
  },
  permissionCard: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
  },
  confirmCard: {
    borderRadius: Spacing.three,
    padding: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
  },
  confirmCover: {
    width: 96,
    height: 144,
    borderRadius: Spacing.two,
  },
  coverPlaceholder: {
    borderStyle: 'dashed',
    borderWidth: 1,
    borderColor: 'rgba(128,128,128,0.4)',
  },
  confirmInput: {
    width: '100%',
    borderRadius: Spacing.two,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    fontSize: 16,
  },
  confirmButtonRow: {
    flexDirection: 'row',
    gap: Spacing.three,
    marginTop: Spacing.one,
  },
  confirmButton: {
    paddingHorizontal: Spacing.four,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.five,
  },
  addButton: {},
  centerText: {
    textAlign: 'center',
  },
  manualRow: {
    gap: Spacing.two,
  },
  manualInputRow: {
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
  lookupButton: {
    paddingHorizontal: Spacing.four,
    justifyContent: 'center',
    borderRadius: Spacing.three,
  },
  pressed: {
    opacity: 0.7,
  },
});
