import { useEffect, useRef } from 'react';
import { StyleSheet } from 'react-native';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';

import { OCR_WORKER_HTML, handleOcrWorkerMessage, registerOcrWorker, unregisterOcrWorker } from '@/lib/ocr';

/**
 * Mounted once at the root layout so it survives screen navigation and keeps
 * running background OCR jobs while the user moves on to capturing the next
 * book. Invisible — this is infrastructure, not UI.
 */
export function OcrWorker() {
  const webviewRef = useRef<WebView>(null);

  useEffect(() => {
    registerOcrWorker((message) => webviewRef.current?.postMessage(message));
    return unregisterOcrWorker;
  }, []);

  function onMessage(event: WebViewMessageEvent) {
    handleOcrWorkerMessage(event.nativeEvent.data);
  }

  return (
    <WebView
      ref={webviewRef}
      source={{ html: OCR_WORKER_HTML }}
      onMessage={onMessage}
      style={styles.hidden}
      javaScriptEnabled
    />
  );
}

const styles = StyleSheet.create({
  hidden: {
    position: 'absolute',
    width: 0,
    height: 0,
    opacity: 0,
  },
});
