import { describe, expect, it } from 'vitest';
import { TopicStream } from '../src/bridge/stream';
import type { UiChange, UiSnapshot } from '../src/bridge/generated';

const snapshot = (revision: string, epoch = '9'): UiSnapshot<string> => ({ epoch, topic: 'settings', revision, value: `v${revision}` });
const change = (revision: string, value = `v${revision}`, epoch = '9'): UiChange<string> => ({ epoch, topic: 'settings', revision, value });

describe('topic stream recovery', () => {
  it('buffers a change that arrives before the snapshot and applies only newer revisions', () => {
    const stream = new TopicStream<string>();
    stream.accept(change('3'));
    const installed = stream.installSnapshot(snapshot('2'));
    expect(installed).toMatchObject({ kind: 'applied', value: { revision: '3', value: 'v3' } });
    expect(stream.accept(change('3')).kind).toBe('ignored');
  });

  it('requests resynchronization on a gap or a runtime epoch restart', () => {
    const stream = new TopicStream<string>();
    stream.installSnapshot(snapshot('4'));
    expect(stream.accept(change('6')).kind).toBe('resync');
    expect(stream.accept(change('5', 'v5', '10')).kind).toBe('resync');
  });

  it('ignores a delayed snapshot or event from an older runtime epoch', () => {
    const stream = new TopicStream<string>();
    stream.installSnapshot(snapshot('2', '10'));
    expect(stream.installSnapshot(snapshot('99', '9')).kind).toBe('ignored');
    expect(stream.accept(change('99', 'stale', '9')).kind).toBe('ignored');
    expect(stream.snapshot()).toMatchObject({ epoch: '10', revision: '2', value: 'v2' });
  });
});
