import type { UiChange, UiSnapshot } from './generated';

export type StreamValue<T> = UiSnapshot<T> | UiChange<T>;
export type StreamResult<T> = { kind: 'applied'; value: UiSnapshot<T> } | { kind: 'resync' } | { kind: 'ignored' };

export class TopicStream<T> {
  private current?: UiSnapshot<T>;
  private buffered: UiChange<T>[] = [];

  accept(value: StreamValue<T>): StreamResult<T> {
    if (!this.current) {
      if ('value' in value && 'revision' in value && 'epoch' in value) this.buffered.push(value as UiChange<T>);
      return { kind: 'ignored' };
    }

    if (value.topic !== this.current.topic) return { kind: 'ignored' };
    const incomingEpoch = BigInt(value.epoch);
    const currentEpoch = BigInt(this.current.epoch);
    if (incomingEpoch < currentEpoch) return { kind: 'ignored' };
    if (incomingEpoch > currentEpoch) return { kind: 'resync' };

    const revision = BigInt(value.revision);
    const currentRevision = BigInt(this.current.revision);
    if (revision <= currentRevision) return { kind: 'ignored' };
    if (revision !== currentRevision + 1n) return { kind: 'resync' };

    this.current = { ...this.current, revision: value.revision, value: value.value };
    return { kind: 'applied', value: this.current };
  }

  installSnapshot(snapshot: UiSnapshot<T>): StreamResult<T> {
    if (this.current && snapshot.topic !== this.current.topic) return { kind: 'ignored' };
    if (this.current) {
      const incomingEpoch = BigInt(snapshot.epoch);
      const currentEpoch = BigInt(this.current.epoch);
      if (incomingEpoch < currentEpoch) return { kind: 'ignored' };
      if (incomingEpoch === currentEpoch && BigInt(snapshot.revision) < BigInt(this.current.revision)) return { kind: 'ignored' };
    }
    this.current = snapshot;
    const buffered = this.buffered;
    this.buffered = [];
    for (const change of buffered) {
      const result = this.accept(change);
      if (result.kind === 'resync') return result;
    }
    return { kind: 'applied', value: this.current };
  }

  snapshot(): UiSnapshot<T> | undefined {
    return this.current;
  }
}

export type UiTopicName = UiSnapshot<unknown>['topic'];
