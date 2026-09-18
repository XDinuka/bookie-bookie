import { File } from 'expo-file-system';
import { Platform } from 'react-native';

// Runs entirely inside a hidden WebView (see ocr-worker.tsx) via tesseract.js,
// since neither ML Kit nor Apple's Vision framework support Sinhala OCR.
// tesseract.js is fetched from a CDN on first run and needs network access
// then; recognition itself runs on-device once the worker is loaded.
export const OCR_WORKER_HTML = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /></head>
<body>
<script src="https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"></script>
<script>
  var worker = null;
  var ready = false;
  var queue = [];

  function post(message) {
    window.ReactNativeWebView.postMessage(JSON.stringify(message));
  }

  function processJob(job) {
    worker
      .recognize(job.imageDataUri)
      .then(function (result) {
        post({ id: job.id, text: result.data.text });
      })
      .catch(function (err) {
        post({ id: job.id, error: String(err && err.message ? err.message : err) });
      });
  }

  function handleIncoming(event) {
    var job;
    try {
      job = JSON.parse(event.data);
    } catch (e) {
      return;
    }
    if (ready) processJob(job);
    else queue.push(job);
  }

  window.addEventListener('message', handleIncoming);
  document.addEventListener('message', handleIncoming);

  Tesseract.createWorker(['sin', 'eng'])
    .then(function (createdWorker) {
      worker = createdWorker;
      ready = true;
      post({ type: 'ready' });
      var pending = queue.splice(0);
      pending.forEach(processJob);
    })
    .catch(function (err) {
      post({ type: 'init-error', error: String(err && err.message ? err.message : err) });
    });
</script>
</body>
</html>
`;

type PendingJob = { resolve: (text: string) => void; reject: (err: Error) => void };

const pendingJobs = new Map<string, PendingJob>();
let postToWorker: ((message: string) => void) | null = null;
let workerReady = false;
let workerInitError: string | null = null;
const readyWaiters: (() => void)[] = [];

export function registerOcrWorker(post: (message: string) => void) {
  postToWorker = post;
}

export function unregisterOcrWorker() {
  postToWorker = null;
  // The worker is unmounted between OCR jobs (see ocr-queue.ts); reset so
  // the next mount's own "ready" message is waited for instead of reusing
  // a stale ready/error flag from the previous instance.
  workerReady = false;
  workerInitError = null;
}

export function markOcrWorkerReady() {
  workerReady = true;
  readyWaiters.splice(0).forEach((resolve) => resolve());
}

export function markOcrWorkerInitError(message: string) {
  workerInitError = message;
  readyWaiters.splice(0).forEach((resolve) => resolve());
}

function waitForWorker(): Promise<void> {
  if (workerReady || workerInitError) return Promise.resolve();
  return new Promise((resolve) => readyWaiters.push(resolve));
}

export function handleOcrWorkerMessage(rawMessage: string) {
  let parsed: { id?: string; text?: string; error?: string; type?: string };
  try {
    parsed = JSON.parse(rawMessage);
  } catch {
    return;
  }

  if (parsed.type === 'ready') {
    markOcrWorkerReady();
    return;
  }
  if (parsed.type === 'init-error') {
    markOcrWorkerInitError(parsed.error ?? 'OCR worker failed to start');
    return;
  }
  if (!parsed.id) return;

  const job = pendingJobs.get(parsed.id);
  if (!job) return;
  pendingJobs.delete(parsed.id);
  if (parsed.error) job.reject(new Error(parsed.error));
  else job.resolve(parsed.text ?? '');
}

function makeJobId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/** Runs OCR on a local photo URI, returning the raw recognized text (Sinhala + English). */
export async function runOcr(imageUri: string): Promise<string> {
  if (Platform.OS === 'web') {
    throw new Error('OCR capture is not supported on web yet — use the mobile app.');
  }

  await waitForWorker();
  if (workerInitError) throw new Error(workerInitError);
  if (!postToWorker) throw new Error('OCR worker is not mounted');

  const file = new File(imageUri);
  const base64 = await file.base64();
  const dataUri = `data:image/jpeg;base64,${base64}`;

  const id = makeJobId();
  return new Promise<string>((resolve, reject) => {
    pendingJobs.set(id, { resolve, reject });
    postToWorker!(JSON.stringify({ id, imageDataUri: dataUri }));
  });
}
