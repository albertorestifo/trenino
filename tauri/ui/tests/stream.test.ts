import { describe, expect, it } from 'vitest';
import { MAX_BUFFERED_CHANGES, TopicStream } from '../src/bridge/stream';
import type { UiChange, UiSnapshot } from '../src/bridge/generated';

const snapshot = (revision: string, epoch = '9'): UiSnapshot<string> => ({ epoch, topic: 'settings', revision, value: `v${revision}` });
const change = (revision: string, value = `v${revision}`, epoch = '9'): UiChange<string> => ({ epoch, topic: 'settings', revision, value });

describe('topic stream recovery', () => {
  it('buffers a change that arrives before the snapshot and applies only newer revisions', () => {
    const stream = new TopicStream<string>('settings');
    stream.accept(change('3'));
    const installed = stream.installSnapshot(snapshot('2'));
    expect(installed).toMatchObject({ kind: 'applied', value: { revision: '3', value: 'v3' } });
    expect(stream.accept(change('3')).kind).toBe('ignored');
  });

  it('requests resynchronization on a gap or a runtime epoch restart', () => {
    const stream = new TopicStream<string>('settings');
    stream.installSnapshot(snapshot('4'));
    expect(stream.accept(change('6')).kind).toBe('resync');
    expect(stream.accept(change('5', 'v5', '10')).kind).toBe('resync');
  });

  it('ignores delayed snapshots and events from an epoch already retired', () => {
    const stream = new TopicStream<string>('settings');
    stream.installSnapshot(snapshot('2', '9'));
    stream.installSnapshot(snapshot('1', '10'));
    expect(stream.installSnapshot(snapshot('99', '9')).kind).toBe('ignored');
    expect(stream.accept(change('99', 'stale', '9')).kind).toBe('ignored');
    expect(stream.snapshot()).toMatchObject({ epoch: '10', revision: '1', value: 'v1' });
  });

  it('keeps observed newer changes across a lagging snapshot and catches up later', () => {
    const stream = new TopicStream<string>('settings');
    stream.installSnapshot(snapshot('4'));
    expect(stream.accept(change('6')).kind).toBe('resync');
    expect(stream.installSnapshot(snapshot('5'))).toMatchObject({ kind: 'applied', value: { revision: '6', value: 'v6' } });
    expect(stream.needsSnapshot()).toBe(false);
  });

  it('retains gap events through replay and catches up across an opaque epoch change', () => {
    const stream = new TopicStream<string>('settings');
    stream.installSnapshot(snapshot('4', '200'));
    stream.accept(change('6', 'six', '201'));
    stream.accept(change('7', 'seven', '201'));
    expect(stream.installSnapshot(snapshot('5', '201')).kind).toBe('applied');
    expect(stream.snapshot()).toMatchObject({ epoch: '201', revision: '7', value: 'seven' });
    expect(stream.accept(change('8', 'old', '200')).kind).toBe('ignored');
  });

  it('bounds pre-snapshot buffering while retaining enough high-water information', () => {
    const stream = new TopicStream<string>('settings');
    for (let revision = 1; revision <= 10_000; revision += 1) stream.accept(change(String(revision)));
    expect(stream.bufferedChangeCount).toBeLessThanOrEqual(MAX_BUFFERED_CHANGES);
    expect(stream.installSnapshot(snapshot('9999'))).toMatchObject({ kind: 'applied', value: { revision: '10000' } });
  });

  it('rejects malformed envelopes without throwing and supports exact u64 counters', () => {
    const stream = new TopicStream<string>('settings');
    expect(stream.accept({ ...change('1'), revision: 'not-an-integer' })).toMatchObject({ kind: 'invalid' });
    expect(stream.installSnapshot({ ...snapshot('1'), epoch: '18446744073709551616' })).toMatchObject({ kind: 'invalid' });
    expect(stream.installSnapshot(snapshot('18446744073709551614', '9')).kind).toBe('applied');
    expect(stream.accept(change('18446744073709551615')).kind).toBe('applied');
    expect(stream.accept({ ...change('18446744073709551616') }).kind).toBe('invalid');
    expect(stream.accept({ ...change('1'), topic: 'trains' as const }).kind).toBe('invalid');
  });
});
