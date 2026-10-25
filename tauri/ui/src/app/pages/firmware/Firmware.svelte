<script lang="ts">
  import { onMount } from 'svelte';
  import type { FirmwareReleaseView, FirmwareView, UploadHistoryView } from '../../../bridge/generated';
  import type { FirmwareUpdateStatus, SerialPortView, UiBridge } from '../../../bridge/client';

  let { bridge, ports = [], refreshPorts, updateStatus = null, refreshUpdateStatus }: {
    bridge: UiBridge; ports?: SerialPortView[]; refreshPorts?: () => Promise<void>;
    updateStatus?: FirmwareUpdateStatus | null; refreshUpdateStatus?: () => Promise<void>;
  } = $props();

  const UPLOAD_POLL_MS = 1000;

  let loading = $state(true);
  let error = $state('');
  let flash = $state('');
  let firmware = $state<FirmwareView | null>(null);
  let checkingUpdates = $state(false);
  const isChecking = $derived(checkingUpdates || updateStatus?.checking === true);
  let environmentFilter = $state('');
  let showOlderReleases = $state(false);

  /** Release/environment pairs downloaded in this session (`ui_download_firmware` succeeded). */
  let downloaded = $state(new Set<string>());
  let downloadPending = $state(new Set<string>());

  let uploadRelease = $state<FirmwareReleaseView | null>(null);
  let uploadEnvironment = $state('');
  let uploadPort = $state('');
  let uploadGeneration = $state<number | null>(null);
  let uploadPhase = $state<'idle' | 'downloading' | 'uploading' | 'done'>('idle');
  let uploadId = $state<string | null>(null);
  let uploadError = $state('');
  let cancelPending = $state(false);
  let cancelRequested = $state(false);
  let pollTimer: ReturnType<typeof setInterval> | undefined;
  let pageActive = false;
  let catalogSequence = 0;
  let seenCheckTime: number | null = null;

  async function refreshCatalog() {
    const sequence = ++catalogSequence;
    const result = await bridge.getFirmware();
    if (pageActive && sequence === catalogSequence && result.ok) firmware = result.value.value;
  }

  $effect(() => {
    const checkedAt = updateStatus?.checked_at_ms ?? null;
    if (!pageActive || loading || checkedAt === null || checkedAt === seenCheckTime) return;
    seenCheckTime = checkedAt;
    void refreshCatalog();
  });

  const environments = $derived.by(() => {
    const set = new Set<string>();
    for (const release of firmware?.releases ?? []) {
      for (const file of release.files) {
        if (file.environment) set.add(file.environment);
      }
    }
    return [...set].sort();
  });

  const releases = $derived(
    environmentFilter === ''
      ? firmware?.releases ?? []
      : (firmware?.releases ?? []).filter((release) => release.files.some((file) => file.environment === environmentFilter)),
  );
  const latestRelease = $derived(releases[0] ?? null);
  const olderReleases = $derived(releases.slice(1));
  const latestCheck = $derived((firmware?.update_checks ?? [])[0] ?? null);
  const uploadHistory = $derived((firmware?.upload_history ?? []).slice(0, 10));

  onMount(() => {
    const unsubscribers: (() => void)[] = [];
    let disposed = false;
    pageActive = true;
    seenCheckTime = updateStatus?.checked_at_ms ?? null;
    void (async () => {
      const sequence = ++catalogSequence;
      const loaded = await bridge.getFirmware();
      if (disposed) return;
      if (loaded.ok && sequence === catalogSequence) {
        firmware = loaded.value.value;
        const running = loaded.value.value.upload_history.find((entry) => entry.status === 'running');
        if (running) {
          uploadId = running.upload_id;
          uploadPort = running.port;
          uploadPhase = 'uploading';
          uploadRelease = loaded.value.value.releases.find((release) => release.files.some((file) => file.id === running.firmware_file_id)) ?? null;
          pollTimer = setInterval(() => void pollUploadStatus(), UPLOAD_POLL_MS);
        }
      } else if (!loaded.ok && sequence === catalogSequence) error = loaded.error.message;
      loading = false;
      const unsubscribe = await bridge.subscribe<FirmwareView>(
        'firmware',
        (snapshot) => {
          catalogSequence += 1;
          firmware = snapshot.value;
        },
        () => {},
      );
      if (disposed) unsubscribe();
      else unsubscribers.push(unsubscribe);
    })();
    return () => {
      disposed = true;
      pageActive = false;
      catalogSequence += 1;
      unsubscribers.forEach((unsubscribe) => unsubscribe());
      if (pollTimer) clearInterval(pollTimer);
    };
  });

  async function checkUpdates() {
    checkingUpdates = true;
    error = '';
    flash = '';
    try {
      const checked = await bridge.checkFirmwareUpdates();
      if (checked.ok) {
        firmware = checked.value.value;
        flash = 'Firmware list refreshed';
      } else {
        error = `Failed to check for updates: ${checked.error.message}`;
      }
    } finally {
      await refreshUpdateStatus?.();
      checkingUpdates = false;
    }
  }

  function releaseFiles(release: FirmwareReleaseView) {
    return environmentFilter === '' ? release.files : release.files.filter((file) => file.environment === environmentFilter);
  }

  function formatBytes(size: number | null): string {
    if (size === null) return 'Size unknown';
    if (size <= 0) return '';
    if (size < 1024 * 1024) return `${Math.max(1, Math.round(size / 1024))} KB`;
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  }

  function formatPublishedAt(value: string | null): string {
    if (!value) return '';
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return value;
    return parsed.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
  }

  function formatTime(value: string | null): string {
    if (!value) return '-';
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return value;
    const hours = String(parsed.getUTCHours()).padStart(2, '0');
    const minutes = String(parsed.getUTCMinutes()).padStart(2, '0');
    const seconds = String(parsed.getUTCSeconds()).padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
  }

  async function downloadFile(releaseId: string, environment: string | null) {
    if (!environment) return;
    const key = `${releaseId}:${environment}`;
    downloadPending = new Set([...downloadPending, key]);
    error = '';
    try {
      const downloadedResult = await bridge.downloadFirmware(releaseId, environment);
      if (downloadedResult.ok) {
        firmware = downloadedResult.value.value;
        downloaded = new Set([...downloaded, key]);
        flash = 'Firmware downloaded';
      } else {
        error = downloadedResult.error.message;
      }
    } finally {
      const next = new Set(downloadPending);
      next.delete(key);
      downloadPending = next;
    }
  }

  function openUploadModal(release: FirmwareReleaseView) {
    uploadRelease = release;
    uploadEnvironment = '';
    const available = ports.filter((entry) => entry.generation !== null);
    uploadPort = available.length === 1 ? available[0].port : '';
    uploadGeneration = available.length === 1 ? available[0].generation : null;
    uploadPhase = 'idle';
    uploadId = null;
    uploadError = '';
    cancelRequested = false;
    flash = '';
    error = '';
    if (pollTimer) clearInterval(pollTimer);
  }

  function closeUploadModal() {
    if (uploadPhase === 'downloading' || uploadPhase === 'uploading') return;
    uploadRelease = null;
    if (pollTimer) clearInterval(pollTimer);
  }

  function uploadFileFor(release: FirmwareReleaseView, environment: string) {
    return release.files.find((file) => file.environment === environment) ?? null;
  }

  async function startUpload() {
    if (!uploadRelease || uploadEnvironment === '') return;
    const target = { port: uploadPort, generation: uploadGeneration };
    if (!target.port || target.generation === null) {
      uploadError = 'Select a serial port before uploading firmware.';
      return;
    }
    uploadError = '';
    flash = '';
    const file = uploadFileFor(uploadRelease, uploadEnvironment);
    if (!file) {
      uploadError = 'No firmware available for this device.';
      return;
    }
    uploadPhase = 'downloading';
    try {
      const downloadedResult = await bridge.downloadFirmware(uploadRelease.id, uploadEnvironment);
      if (!downloadedResult.ok) {
        uploadError = `Failed to start upload: ${downloadedResult.error.message}`;
        uploadPhase = 'idle';
        return;
      }
      firmware = downloadedResult.value.value;
      downloaded = new Set([...downloaded, `${uploadRelease.id}:${uploadEnvironment}`]);
      uploadPhase = 'uploading';
      const currentPorts = await bridge.serialPorts();
      if (!currentPorts.ok) {
        uploadError = currentPorts.error.message;
        uploadPhase = 'idle';
        return;
      }
      if (!currentPorts.value.some((entry) => entry.port === target.port && entry.generation === target.generation)) {
        uploadError = 'The serial port changed during download. Select its current connection and try again.';
        uploadPhase = 'idle';
        return;
      }
      const started = await bridge.startFirmwareUpload(file.id, target.port, uploadEnvironment, target.generation);
      if (!started.ok) {
        uploadError = `Failed to start upload: ${started.error.message}`;
        uploadPhase = 'idle';
        return;
      }
      uploadId = started.value;
      pollTimer = setInterval(() => void pollUploadStatus(), UPLOAD_POLL_MS);
    } catch {
      uploadError = 'Firmware upload could not be started. Try again.';
      uploadPhase = 'idle';
    }
  }

  async function pollUploadStatus() {
    if (!uploadId) return;
    const status = await bridge.getFirmware();
    if (!status.ok) { uploadError = status.error.message; return; }
    firmware = status.value.value;
    const entry = status.value.value.upload_history.find((candidate) => candidate.upload_id === uploadId);
    if (!entry || entry.status === 'running') return;
    finishUpload(entry);
  }

  function finishUpload(entry: UploadHistoryView) {
    if (pollTimer) clearInterval(pollTimer);
    uploadPhase = 'done';
    uploadId = null;
    if (entry.status === 'success') {
      uploadRelease = null;
      flash = entry.duration_ms === null ? 'Firmware uploaded successfully.' : `Firmware uploaded successfully in ${entry.duration_ms}ms`;
    } else if (entry.status === 'cancelled') {
      uploadError = 'Upload cancelled.';
    } else {
      uploadError = entry.error_message ?? 'Upload failed.';
    }
  }

  async function cancelUpload() {
    if (!uploadId || cancelPending || cancelRequested) return;
    cancelPending = true;
    const cancelled = await bridge.cancelFirmwareUpload(uploadId);
    cancelPending = false;
    if (!cancelled.ok) {
      uploadError = cancelled.error.message;
      return;
    }
    cancelRequested = true;
    void pollUploadStatus();
  }

  function statusBadge(status: string): { variant: string; label: string } {
    switch (status) {
      case 'success':
        return { variant: 'badge-success', label: 'Success' };
      case 'failed':
        return { variant: 'badge-error', label: 'Failed' };
      case 'cancelled':
        return { variant: 'badge-warning', label: 'Cancelled' };
      default:
        return { variant: 'badge-info', label: 'In Progress' };
    }
  }
</script>

<div class="max-w-4xl mx-auto">
  <header class="mb-8 flex flex-wrap items-center justify-between gap-4">
    <div>
      <h1 class="text-2xl font-semibold">Firmware</h1>
      <p class="text-sm text-base-content/70 mt-1">Download and upload firmware to your devices</p>
    </div>
    <button type="button" class="btn btn-primary" disabled={isChecking} onclick={() => void checkUpdates()} data-testid="check-updates">
      {isChecking ? 'Checking...' : 'Check for Updates'}
    </button>
  </header>

  {#if error}
    <div role="alert" class="alert alert-error mb-6">{error}</div>
  {/if}
  {#if updateStatus?.error_message && !error}
    <div role="status" class="alert alert-error mb-6">Last firmware check failed: {updateStatus.error_message}</div>
  {/if}
  {#if flash}
    <div role="status" class="alert alert-info mb-6">{flash}</div>
  {/if}

  {#if updateStatus?.checked_at_ms && !latestCheck}
    <p class="text-sm text-base-content/70 mb-8" data-testid="latest-update-check">Last checked {new Date(updateStatus.checked_at_ms).toLocaleString()}</p>
  {:else if latestCheck}
    <div class="text-sm text-base-content/70 mb-8" data-testid="latest-update-check">
      Last checked {formatTime(latestCheck.checked_at)}:
      {#if latestCheck.error_message}
        <span class="text-error">{latestCheck.error_message}</span>
      {:else if latestCheck.found_updates}
        update available (v{latestCheck.latest_version})
      {:else}
        no updates found
      {/if}
    </div>
  {/if}

  {#if loading}
    <div class="py-16 flex items-center justify-center" role="status">
      <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
  {:else if (firmware?.releases ?? []).length === 0}
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <span class="text-6xl text-base-content/20" aria-hidden="true">▤</span>
      <h2 class="mt-6 text-xl font-semibold">No Firmware Releases</h2>
      <p class="mt-2 text-base-content/70 max-w-sm">
        {isChecking
          ? 'Checking for updates...'
          : "Click 'Check for Updates' to fetch available firmware versions from GitHub."}
      </p>
    </div>
  {:else}
    <section aria-labelledby="releases-title">
      <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
        <h2 id="releases-title" class="text-lg font-medium">Available Releases</h2>
        <label class="flex items-center gap-2 text-sm">
          <span class="text-base-content/70">Environment</span>
          <select class="select select-bordered select-sm" bind:value={environmentFilter} data-testid="environment-filter">
            <option value="">All environments</option>
            {#each environments as environment (environment)}
              <option value={environment}>{environment}</option>
            {/each}
          </select>
        </label>
      </div>
      <div class="space-y-4">
        {#if latestRelease}
          <div class="border-2 border-primary/30 bg-base-200/80 shadow-lg shadow-primary/5 rounded-xl p-6" data-testid="release-card">
            <div class="flex items-start justify-between gap-4">
              <div>
                <div class="flex items-center gap-2 flex-wrap">
                  <h3 class="font-medium">v{latestRelease.version}</h3>
                  <span class="badge badge-ghost badge-sm">{latestRelease.tag_name}</span>
                  <span class="badge badge-success badge-sm">Latest</span>
                </div>
                {#if latestRelease.published_at}
                  <p class="text-xs text-base-content/60 mt-1">Released {formatPublishedAt(latestRelease.published_at)}</p>
                {/if}
                <ul class="mt-3 space-y-2">
                  {#each releaseFiles(latestRelease) as file (file.id)}
                    <li class="text-sm flex flex-wrap items-center gap-2">
                      <span class="badge badge-ghost badge-sm">{file.environment ?? file.board_type}</span>
                      <span class="text-base-content/60">{formatBytes(file.file_size)}</span>
                      <button
                        type="button"
                        class="btn btn-outline btn-xs"
                        disabled={downloadPending.has(`${latestRelease.id}:${file.environment}`)}
                        onclick={() => void downloadFile(latestRelease.id, file.environment)}
                        data-testid="download-firmware"
                      >
                        {#if downloadPending.has(`${latestRelease.id}:${file.environment}`)}
                          <span class="loading loading-spinner loading-xs"></span> Downloading…
                        {:else if downloaded.has(`${latestRelease.id}:${file.environment}`)}
                          Downloaded
                        {:else}
                          Download
                        {/if}
                      </button>
                    </li>
                  {/each}
                </ul>
              </div>
              <div class="flex gap-2 items-center shrink-0">
                <button type="button" class="btn btn-primary btn-sm" onclick={() => openUploadModal(latestRelease)} data-testid="upload-to-device">
                  Upload to Device
                </button>
                {#if latestRelease.release_url}
                  <a href={latestRelease.release_url} target="_blank" rel="noreferrer" class="btn btn-ghost btn-sm" aria-label="Open release on GitHub">↗</a>
                {/if}
              </div>
            </div>
          </div>
        {/if}

        {#if olderReleases.length > 0}
          <button
            type="button"
            class="btn btn-ghost btn-sm w-full justify-start text-base-content/70 hover:text-base-content"
            onclick={() => (showOlderReleases = !showOlderReleases)}
            data-testid="toggle-older-releases"
          >
            {showOlderReleases ? 'Hide older releases' : `Show ${olderReleases.length} older release${olderReleases.length > 1 ? 's' : ''}`}
          </button>
          {#if showOlderReleases}
            <div class="space-y-4">
              {#each olderReleases as release (release.id)}
                <div class="border border-base-300 bg-base-200/50 rounded-xl p-5" data-testid="release-card">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <div class="flex items-center gap-2 flex-wrap">
                        <h3 class="font-medium">v{release.version}</h3>
                        <span class="badge badge-ghost badge-sm">{release.tag_name}</span>
                      </div>
                      {#if release.published_at}
                        <p class="text-xs text-base-content/60 mt-1">Released {formatPublishedAt(release.published_at)}</p>
                      {/if}
                      <ul class="mt-3 space-y-2">
                        {#each releaseFiles(release) as file (file.id)}
                          <li class="text-sm flex flex-wrap items-center gap-2">
                            <span class="badge badge-ghost badge-sm">{file.environment ?? file.board_type}</span>
                            <span class="text-base-content/60">{formatBytes(file.file_size)}</span>
                            <button
                              type="button"
                              class="btn btn-outline btn-xs"
                              disabled={downloadPending.has(`${release.id}:${file.environment}`)}
                              onclick={() => void downloadFile(release.id, file.environment)}
                              data-testid="download-firmware"
                            >
                              {#if downloadPending.has(`${release.id}:${file.environment}`)}
                                <span class="loading loading-spinner loading-xs"></span> Downloading…
                              {:else if downloaded.has(`${release.id}:${file.environment}`)}
                                Downloaded
                              {:else}
                                Download
                              {/if}
                            </button>
                          </li>
                        {/each}
                      </ul>
                    </div>
                    <div class="flex gap-2 items-center shrink-0">
                      <button type="button" class="btn btn-outline btn-sm" onclick={() => openUploadModal(release)} data-testid="upload-to-device">
                        Upload to Device
                      </button>
                      {#if release.release_url}
                        <a href={release.release_url} target="_blank" rel="noreferrer" class="btn btn-ghost btn-sm" aria-label="Open release on GitHub">↗</a>
                      {/if}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        {/if}
      </div>
    </section>

    {#if uploadHistory.length > 0}
      <section class="mt-8" aria-labelledby="upload-history-title">
        <h2 id="upload-history-title" class="text-lg font-medium mb-4">Upload History</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm" data-testid="upload-history">
            <thead>
              <tr>
                <th>Port</th>
                <th>Board</th>
                <th>Status</th>
                <th>Duration</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {#each uploadHistory as entry (entry.id)}
                {@const badge = statusBadge(entry.status)}
                <tr>
                  <td class="font-mono text-xs">{entry.port}</td>
                  <td>{entry.board_type}</td>
                  <td><span class="badge badge-sm {badge.variant}">{badge.label}</span></td>
                  <td>{entry.duration_ms !== null && entry.duration_ms > 0 ? `${entry.duration_ms}ms` : '-'}</td>
                  <td class="text-xs text-base-content/60">{formatTime(entry.started_at)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </section>
    {/if}
  {/if}
</div>

{#if uploadRelease}
  <div class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="upload-modal-title">
    <div class="w-full max-w-lg rounded-xl bg-base-100 p-6 shadow-xl">
      {#if uploadPhase !== 'uploading'}
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          onclick={closeUploadModal}
          aria-label="Close upload dialog"
          data-testid="close-upload-modal"
        >
          ✕
        </button>
      {/if}

      <h3 id="upload-modal-title" class="font-bold text-lg">Upload Firmware</h3>
      <p class="text-sm text-base-content/70 mt-1">
        Version: <span class="font-semibold">v{uploadRelease.version}</span>
      </p>

      {#if uploadPhase === 'idle' || uploadPhase === 'done'}
        <div class="mt-4 space-y-4">
          <label class="block">
            <span class="text-sm font-medium">Device type</span>
            <select
              class="select select-bordered w-full mt-1"
              bind:value={uploadEnvironment}
              data-testid="upload-environment"
            >
              <option value="" disabled selected={uploadEnvironment === ''}>Select your device type</option>
              {#each releaseFiles(uploadRelease) as file (file.id)}
                {#if file.environment}
                  <option value={file.environment}>{file.environment}</option>
                {/if}
              {/each}
            </select>
            <span class="text-xs text-base-content/60">Make sure this matches your physical board</span>
          </label>

          <label class="block">
            <span class="text-sm font-medium">Serial port</span>
            <select class="select select-bordered w-full font-mono mt-1" value={uploadPort} onchange={(event) => {
              uploadPort = event.currentTarget.value;
              uploadGeneration = ports.find((entry) => entry.port === uploadPort)?.generation ?? null;
            }} data-testid="upload-port">
              <option value="">Select serial port</option>
              {#each ports.filter((entry) => entry.generation !== null) as entry (entry.port)}
                <option value={entry.port}>{entry.port} ({entry.status})</option>
              {/each}
            </select>
            <span class="text-xs text-base-content/60">Select the physical board to update, including boards awaiting their first configuration.</span>
          </label>
          <button type="button" class="btn btn-ghost btn-sm" onclick={() => void refreshPorts?.()}>Refresh ports</button>

          <div class="alert alert-warning">
            <div class="text-sm">
              <p class="font-medium">Do not disconnect the device during upload</p>
              <p class="text-base-content/70">Interrupting the upload may corrupt the firmware.</p>
            </div>
          </div>
        </div>
      {:else}
        <div class="mt-4 space-y-4">
          <div class="text-center py-4">
            <span class="text-5xl text-primary inline-block animate-pulse" aria-hidden="true">▤</span>
            <p class="mt-2 text-sm text-base-content/70" data-testid="upload-status">
              {uploadPhase === 'downloading' ? 'Downloading firmware...' : 'Uploading…'}
            </p>
          </div>
          <progress class="progress progress-primary w-full" max="100" aria-label="Upload progress"></progress>
          <p class="text-center text-xs text-base-content/60">
            Uploading to <span class="font-mono">{uploadPort}</span> - Do not disconnect
          </p>
        </div>
      {/if}

      {#if uploadError}
        <div class="alert alert-error mt-4" role="alert">
          <span class="text-sm whitespace-pre-wrap">{uploadError}</span>
        </div>
      {/if}

      <div class="modal-action">
        {#if uploadPhase !== 'uploading' && uploadPhase !== 'downloading'}
          <button type="button" class="btn btn-ghost" onclick={closeUploadModal}>Cancel</button>
          <button
            type="button"
            class="btn btn-primary"
            disabled={uploadEnvironment === '' || uploadPort === '' || uploadGeneration === null}
            onclick={() => void startUpload()}
            data-testid="start-upload"
          >
            Start Upload
          </button>
        {:else if uploadPhase === 'uploading'}
          <button type="button" class="btn btn-error" disabled={cancelPending || cancelRequested} onclick={() => void cancelUpload()} data-testid="cancel-upload">
            {cancelPending ? 'Requesting cancellation…' : cancelRequested ? 'Cancellation requested…' : 'Cancel Upload'}
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}
