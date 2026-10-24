import type { UiChange, UiSnapshot } from './generated';

export const MAX_BUFFERED_CHANGES = 128;
const MAX_TRACKED_EPOCHS = 8;
const MAX_RETIRED_EPOCHS = 16;
const MAX_COUNTER = 18_446_744_073_709_551_615n;
const COUNTER_PATTERN = /^(0|[1-9][0-9]*)$/;

export type StreamResult<T> =
  | { kind: 'applied'; value: UiSnapshot<T> }
  | { kind: 'resync'; value?: UiSnapshot<T> }
  | { kind: 'ignored' }
  | { kind: 'invalid'; message: string };

export interface SnapshotRequestToken {
  observationGeneration: number;
  overflowGeneration: number;
}

type Envelope<T> = UiSnapshot<T> | UiChange<T>;
type Validated<T> = { ok: true; value: Envelope<T> } | { ok: false; message: string };

function counter(value: unknown): bigint | undefined {
  if (typeof value !== 'string' || !COUNTER_PATTERN.test(value)) return undefined;
  try {
    const parsed = BigInt(value);
    return parsed <= MAX_COUNTER ? parsed : undefined;
  } catch {
    return undefined;
  }
}

function validateEnvelope<T>(input: unknown, topic: UiSnapshot<unknown>['topic']): Validated<T> {
  if (input === null || typeof input !== 'object' || Array.isArray(input)) return { ok: false, message: 'Snapshot/change must be an object.' };
  const value = input as Record<string, unknown>;
  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) return { ok: false, message: 'Snapshot/change must be a plain object.' };
  if (value.topic !== topic) return { ok: false, message: 'Snapshot/change topic does not match this subscription.' };
  if (counter(value.epoch) === undefined) return { ok: false, message: 'Snapshot/change has an invalid runtime epoch.' };
  if (counter(value.revision) === undefined) return { ok: false, message: 'Snapshot/change has an invalid revision.' };
  if (!Object.hasOwn(value, 'value')) return { ok: false, message: 'Snapshot/change has no value.' };
  return { ok: true, value: input as Envelope<T> };
}

function changeKey(change: UiChange<unknown>): string {
  return `${change.epoch}:${change.revision}`;
}

export class TopicStream<T> {
  private current?: UiSnapshot<T>;
  private readonly pending = new Map<string, UiChange<T>>();
  private readonly droppedHighWater = new Map<string, bigint>();
  private readonly retiredEpochs: string[] = [];
  private observationGeneration = 0;
  private overflowGeneration = 0;
  private coveredOverflowGeneration = 0;

  constructor(private readonly topic: UiSnapshot<unknown>['topic']) {}

  get bufferedChangeCount(): number {
    return this.pending.size;
  }

  beginSnapshot(): SnapshotRequestToken {
    return {
      observationGeneration: this.observationGeneration,
      overflowGeneration: this.overflowGeneration,
    };
  }

  accept(input: unknown): StreamResult<T> {
    const validated = validateEnvelope<T>(input, this.topic);
    if (!validated.ok) return { kind: 'invalid', message: validated.message };

    const change = validated.value as UiChange<T>;
    const changeRevision = counter(change.revision)!;
    if (this.isRetired(change.epoch)) return { kind: 'ignored' };
    if (this.current?.epoch === change.epoch && changeRevision <= counter(this.current.revision)!) return { kind: 'ignored' };
    this.observationGeneration += 1;
    this.remember(change, changeRevision);
    if (!this.current) return { kind: 'resync' };
    if (change.epoch !== this.current.epoch) return { kind: 'resync', value: this.current };

    this.replayCurrentEpoch();
    return this.needsSnapshot() ? { kind: 'resync', value: this.current } : { kind: 'applied', value: this.current };
  }

  installSnapshot(input: unknown, request: SnapshotRequestToken = this.beginSnapshot()): StreamResult<T> {
    const validated = validateEnvelope<T>(input, this.topic);
    if (!validated.ok) return { kind: 'invalid', message: validated.message };

    const snapshot = validated.value as UiSnapshot<T>;
    const snapshotRevision = counter(snapshot.revision)!;
    if (this.isRetired(snapshot.epoch)) return this.needsSnapshot() ? { kind: 'resync', value: this.current } : { kind: 'ignored' };

    if (this.current && snapshot.epoch === this.current.epoch && snapshotRevision < counter(this.current.revision)!) {
      return { kind: 'ignored' };
    }
    if (this.current && snapshot.epoch !== this.current.epoch) this.retire(this.current.epoch);

    this.current = snapshot;
    if (request.observationGeneration === this.observationGeneration && request.overflowGeneration === this.overflowGeneration) {
      this.coveredOverflowGeneration = request.overflowGeneration;
      this.retireOtherEpochs(snapshot.epoch);
    }
    this.replayCurrentEpoch();
    return this.needsSnapshot() ? { kind: 'resync', value: this.current } : { kind: 'applied', value: this.current };
  }

  needsSnapshot(): boolean {
    if (this.coveredOverflowGeneration < this.overflowGeneration) return true;
    if (!this.current) return this.pending.size > 0 || this.droppedHighWater.size > 0;

    const epoch = this.current.epoch;
    const revision = counter(this.current.revision)!;
    if ([...this.pending.values()].some((change) => change.epoch !== epoch && !this.isRetired(change.epoch))) return true;
    if ([...this.pending.values()].some((change) => change.epoch === epoch && counter(change.revision)! > revision)) return true;
    for (const [unresolvedEpoch, highWater] of this.droppedHighWater) {
      if (this.isRetired(unresolvedEpoch)) continue;
      if (unresolvedEpoch !== epoch || highWater > revision) return true;
    }
    return false;
  }

  snapshot(): UiSnapshot<T> | undefined {
    return this.current;
  }

  private remember(change: UiChange<T>, revision: bigint): void {
    this.pending.set(changeKey(change), change);
    const previous = this.droppedHighWater.get(change.epoch);
    if (previous !== undefined && revision > previous) this.droppedHighWater.set(change.epoch, revision);

    while (this.pending.size > MAX_BUFFERED_CHANGES) {
      const oldestKey = this.pending.keys().next().value as string | undefined;
      if (!oldestKey) break;
      const oldest = this.pending.get(oldestKey)!;
      const oldRevision = counter(oldest.revision)!;
      this.pending.delete(oldestKey);
      this.recordDroppedHighWater(oldest.epoch, oldRevision);
    }
  }

  private replayCurrentEpoch(): void {
    if (!this.current) return;
    let currentRevision = counter(this.current.revision)!;
    const changes = [...this.pending.values()]
      .filter((change) => change.epoch === this.current!.epoch)
      .sort((left, right) => {
        const a = counter(left.revision)!;
        const b = counter(right.revision)!;
        return a < b ? -1 : a > b ? 1 : 0;
      });

    for (const change of changes) {
      const revision = counter(change.revision)!;
      if (revision <= currentRevision) {
        this.pending.delete(changeKey(change));
      } else if (revision === currentRevision + 1n) {
        this.current = { ...this.current, revision: change.revision, value: change.value };
        currentRevision = revision;
        this.pending.delete(changeKey(change));
      } else {
        break;
      }
    }

    const dropped = this.droppedHighWater.get(this.current.epoch);
    if (dropped !== undefined && dropped <= currentRevision) this.droppedHighWater.delete(this.current.epoch);
  }

  private isRetired(epoch: string): boolean {
    return this.retiredEpochs.includes(epoch);
  }

  private retire(epoch: string): void {
    if (!this.isRetired(epoch)) this.retiredEpochs.push(epoch);
    for (const [key, change] of this.pending) {
      if (change.epoch === epoch) this.pending.delete(key);
    }
    this.droppedHighWater.delete(epoch);
    while (this.retiredEpochs.length > MAX_RETIRED_EPOCHS) this.retiredEpochs.shift();
  }

  private retireOtherEpochs(authoritativeEpoch: string): void {
    const epochs = new Set<string>([
      ...[...this.pending.values()].map((change) => change.epoch),
      ...this.droppedHighWater.keys(),
    ]);
    for (const epoch of epochs) {
      if (epoch !== authoritativeEpoch) this.retire(epoch);
    }
  }

  private recordDroppedHighWater(epoch: string, revision: bigint): void {
    if (this.isRetired(epoch)) return;
    const previous = this.droppedHighWater.get(epoch);
    if (previous !== undefined) {
      if (revision > previous) this.droppedHighWater.set(epoch, revision);
      return;
    }

    if (this.droppedHighWater.size >= MAX_TRACKED_EPOCHS) {
      const evict = [...this.droppedHighWater.keys()].find((candidate) => candidate !== this.current?.epoch);
      if (evict !== undefined) {
        this.droppedHighWater.delete(evict);
        this.overflowGeneration += 1;
      } else if (epoch !== this.current?.epoch) {
        // Preserve the fact of lost recovery metadata until a fresh snapshot covers it.
        this.overflowGeneration += 1;
        return;
      }
    }
    this.droppedHighWater.set(epoch, revision);
  }
}
