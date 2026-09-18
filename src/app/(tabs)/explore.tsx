import { CameraView, useCameraPermissions, type BarcodeScanningResult } from 'expo-camera';
import { useRef, useState } from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BookConfirmCard, type BookDraft } from '@/components/book-confirm-card';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { addBook, findBookByIsbn } from '@/lib/book-store';
import { isValidIsbn, lookupIsbn, normalizeIsbn } from '@/lib/isbn';

type Stage =
  | { kind: 'scanning' }
  | { kind: 'looking-up'; isbn: string }
  | { kind: 'duplicate'; isbn: string; title: string }
  | { kind: 'confirm'; draft: BookDraft; foundOnline: boolean }
  | { kind: 'added'; title: string };

export default function ScanScreen() {
  const theme = useTheme();
  const safeAreaInsets = useSafeAreaInsets();
  const [permission, requestPermission] = useCameraPermissions();
  const [stage, setStage] = useState<Stage>({ kind: 'scanning' });
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
    setStage({ kind: 'scanning' });
  }

  async function handleBarcodeScanned(scanResult: BarcodeScanningResult) {
    if (stage.kind !== 'scanning' || processingRef.current) return;
    const isbn = normalizeIsbn(scanResult.data);
    if (!isValidIsbn(isbn)) return;

    processingRef.current = true;
    const requestId = requestIdRef.current;

    const existing = findBookByIsbn(isbn);
    if (existing) {
      setStage({ kind: 'duplicate', isbn, title: existing.title });
      return;
    }

    setStage({ kind: 'looking-up', isbn });
    const lookupResult = await lookupIsbn(isbn);
    if (requestIdRef.current !== requestId) return; // cancelled while looking up

    setStage({
      kind: 'confirm',
      draft: {
        isbn,
        title: lookupResult?.title ?? '',
        author: lookupResult?.author ?? '',
        coverUrl: lookupResult?.coverUrl ?? null,
      },
      foundOnline: lookupResult != null,
    });
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
    setTimeout(resetScan, 1200);
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background }, contentPlatformStyle]}>
      <View style={styles.inner}>
        <ThemedText type="subtitle">Scan a Book</ThemedText>

        {!permission ? (
          <ActivityIndicator />
        ) : !permission.granted ? (
          <ThemedView type="backgroundElement" style={styles.messageCard}>
            <ThemedText type="small" style={styles.centerText}>
              Camera access is needed to scan a book&apos;s barcode.
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
            <ThemedText type="small" themeColor="textSecondary" style={styles.centerText}>
              No barcode, or it&apos;s not scanning? Use the Add tab instead.
            </ThemedText>
          </View>
        ) : stage.kind === 'looking-up' ? (
          <ThemedView type="backgroundElement" style={styles.messageCard}>
            <ActivityIndicator />
            <ThemedText type="small" themeColor="textSecondary">
              Looking up ISBN {stage.isbn}…
            </ThemedText>
            <Pressable
              onPress={resetScan}
              style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}>
              <ThemedText type="smallBold" themeColor="textSecondary">
                Cancel
              </ThemedText>
            </Pressable>
          </ThemedView>
        ) : stage.kind === 'duplicate' ? (
          <ThemedView type="backgroundElement" style={styles.messageCard}>
            <ThemedText type="smallBold" style={styles.centerText}>
              &ldquo;{stage.title}&rdquo; is already in your library
            </ThemedText>
            <ThemedText type="code" themeColor="textSecondary">
              ISBN {stage.isbn}
            </ThemedText>
            <Pressable
              onPress={resetScan}
              style={({ pressed }) => [
                styles.actionButton,
                { backgroundColor: theme.backgroundSelected },
                pressed && styles.pressed,
              ]}>
              <ThemedText type="smallBold">Scan another</ThemedText>
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
            onCancel={resetScan}
            onConfirm={() => handleAdd(stage.draft)}
          />
        ) : stage.kind === 'added' ? (
          <ThemedView type="backgroundElement" style={styles.messageCard}>
            <ThemedText type="smallBold">Added &ldquo;{stage.title}&rdquo; to your library</ThemedText>
          </ThemedView>
        ) : null}
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
  centerText: {
    textAlign: 'center',
  },
  pressed: {
    opacity: 0.7,
  },
});
