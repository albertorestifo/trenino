<script lang="ts">
  import type { SequenceView } from '../../../bridge/generated';
  import type { UiBridge } from '../../../bridge/client';
  import EndpointBrowser from '../../../components/EndpointBrowser.svelte';

  let {
    bridge,
    trainId,
    sequences,
    onChanged,
  }: {
    bridge: UiBridge;
    trainId: string;
    sequences: SequenceView[];
    onChanged: () => void;
  } = $props();

  type EditableCommand = { endpoint: string; value: string; delay: string };

  let showAdd = $state(false);
  let newName = $state('');
  let error = $state('');
  let pending = $state(false);

  let editing = $state<SequenceView | null>(null);
  let editingCommands = $state<EditableCommand[]>([]);
  let confirmDelete = $state<SequenceView | null>(null);

  let testingId = $state<string | null>(null);
  let testingStep = $state(-1);
  let testMessage = $state('');

  function openAdd() {
    showAdd = true;
    newName = '';
    error = '';
  }

  async function createSequence() {
    if (newName.trim() === '') return;
    error = '';
    pending = true;
    try {
      const created = await bridge.createSequence(trainId, newName.trim());
      if (!created.ok) {
        error = created.error.message;
        return;
      }
      showAdd = false;
      newName = '';
      onChanged();
    } finally {
      pending = false;
    }
  }

  function openEdit(sequence: SequenceView) {
    editing = sequence;
    error = '';
    editingCommands = sequence.commands
      .slice()
      .sort((a, b) => a.position - b.position)
      .map((command) => ({ endpoint: command.endpoint, value: String(command.value), delay: String(command.delay_ms) }));
  }

  function addCommand() {
    editingCommands.push({ endpoint: '', value: '1', delay: '0' });
  }

  function removeCommand(index: number) {
    editingCommands.splice(index, 1);
  }

  function moveCommand(index: number, delta: -1 | 1) {
    const target = index + delta;
    if (target < 0 || target >= editingCommands.length) return;
    const [command] = editingCommands.splice(index, 1);
    editingCommands.splice(target, 0, command);
  }

  async function saveCommands() {
    if (!editing) return;
    error = '';
    pending = true;
    try {
      const saved = await bridge.setSequenceCommands(
        editing.id,
        editingCommands.map((command) => ({
          endpoint: command.endpoint.trim(),
          value: Number.parseFloat(command.value) || 0,
          delay_ms: Math.max(0, Math.trunc(Number.parseInt(command.delay, 10) || 0)),
        })),
      );
      if (!saved.ok) {
        error = saved.error.message;
        return;
      }
      editing = null;
      editingCommands = [];
      onChanged();
    } finally {
      pending = false;
    }
  }

  async function deleteSequence() {
    if (!confirmDelete) return;
    error = '';
    pending = true;
    try {
      const removed = await bridge.deleteSequence(confirmDelete.id);
      if (!removed.ok) {
        error = removed.error.message;
        return;
      }
      confirmDelete = null;
      onChanged();
    } finally {
      pending = false;
    }
  }

  function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async function testSequence(sequence: SequenceView) {
    if (sequence.commands.length === 0) {
      testMessage = 'Sequence has no commands to test';
      return;
    }
    error = '';
    testMessage = '';
    testingId = sequence.id;
    testingStep = -1;
    const run = bridge.testSequence(sequence.id);
    try {
      for (let index = 0; index < sequence.commands.length; index += 1) {
        testingStep = index;
        const commandDelay = sequence.commands[index].delay_ms;
        if (commandDelay > 0) await delay(commandDelay);
        else await Promise.resolve();
      }
      const result = await run;
      if (!result.ok) {
        testMessage = result.error.message;
        return;
      }
      testingStep = sequence.commands.length;
      testMessage = result.value
        ? `Testing sequence: ${sequence.name}`
        : 'The simulator is not reachable; commands were skipped.';
    } finally {
      testingId = null;
    }
  }
</script>

<div>
  <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
    <h3 class="text-base font-semibold">Sequences</h3>
    <button type="button" class="btn btn-outline btn-sm" onclick={openAdd} data-testid="new-sequence">
      New Sequence
    </button>
  </div>

  {#if error}
    <p role="alert" class="text-sm text-error mb-3">{error}</p>
  {/if}
  {#if testMessage}
    <p role="status" class="text-sm text-muted mb-3" data-testid="sequence-test-message">{testMessage}</p>
  {/if}

  {#if sequences.length === 0}
    <p class="text-sm text-muted py-3">
      No sequences defined. Execute multiple commands from a single button press.
    </p>
  {:else}
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg" data-testid="sequence-table">
        <thead>
          <tr class="bg-base-200">
            <th>Name</th>
            <th>Commands</th>
            <th class="w-48"></th>
          </tr>
        </thead>
        <tbody>
          {#each sequences as sequence (sequence.id)}
            {@const commandCount = sequence.commands.length}
            <tr class="hover:bg-base-200/50">
              <td class="font-medium">{sequence.name}</td>
              <td>
                <span class="text-sm text-muted">
                  {commandCount} command{commandCount !== 1 ? 's' : ''}
                </span>
                {#if testingId === sequence.id}
                  <span class="ml-2 loading loading-spinner loading-xs text-primary" aria-label="Testing"></span>
                  {#if testingStep >= 0}
                    <span class="ml-1 text-xs text-muted" data-testid="sequence-test-progress">
                      Step {Math.min(testingStep + 1, commandCount)} of {commandCount}
                    </span>
                  {/if}
                {/if}
              </td>
              <td>
                <div class="flex gap-1">
                  <button
                    type="button"
                    class="btn btn-ghost btn-xs text-success"
                    title="Test sequence"
                    disabled={commandCount === 0 || testingId !== null}
                    onclick={() => void testSequence(sequence)}
                    data-testid="test-sequence"
                  >
                    ▶
                  </button>
                  <button type="button" class="btn btn-ghost btn-xs" title="Edit" onclick={() => openEdit(sequence)} data-testid="edit-sequence">
                    ✎
                  </button>
                  <button
                    type="button"
                    class="btn btn-ghost btn-xs text-error"
                    title="Delete"
                    onclick={() => (confirmDelete = sequence)}
                    data-testid="delete-sequence"
                  >
                    🗑
                  </button>
                </div>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}

  {#if showAdd}
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-labelledby="new-sequence-title">
      <div class="absolute inset-0 bg-black/50" onclick={() => (showAdd = false)} aria-hidden="true"></div>
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-sm p-6">
        <h2 id="new-sequence-title" class="text-lg font-semibold mb-4">New Sequence</h2>
        <label class="block mb-4">
          <span class="text-sm font-medium">Name</span>
          <input
            type="text"
            class="input input-bordered w-full mt-1"
            bind:value={newName}
            placeholder="e.g., Door Open, Horn Sequence"
            data-testid="new-sequence-name"
          />
        </label>
        <div class="flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (showAdd = false)}>Cancel</button>
          <button
            type="button"
            class="btn btn-primary"
            disabled={pending || newName.trim() === ''}
            onclick={() => void createSequence()}
            data-testid="create-sequence"
          >
            Create
          </button>
        </div>
      </div>
    </div>
  {/if}

  {#if editing}
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-labelledby="edit-sequence-title">
      <div class="absolute inset-0 bg-black/50" onclick={() => (editing = null)} aria-hidden="true"></div>
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div class="p-6 border-b border-base-300">
          <h2 id="edit-sequence-title" class="text-lg font-semibold">{editing.name}</h2>
          <p class="text-sm text-muted">
            Commands execute in order. Delay specifies wait time after each command.
          </p>
        </div>
        <div class="flex-1 overflow-y-auto p-6">
          <div class="space-y-3">
            {#each editingCommands as command, index (index)}
              <div class="bg-base-200/50 rounded-lg p-4">
                <div class="flex items-start gap-3">
                  <div class="flex-none w-8 pt-2 text-center">
                    <span class="text-sm font-semibold text-muted">{index + 1}</span>
                  </div>
                  <div class="flex-1 grid grid-cols-3 gap-3">
                    <div class="col-span-2">
                      <span class="label py-1"><span class="label-text text-xs">Endpoint</span></span>
                      <input
                        type="text"
                        class="input input-bordered input-sm w-full font-mono"
                        bind:value={command.endpoint}
                        placeholder="CurrentDrivableActor/…"
                        data-testid="sequence-command-endpoint"
                        aria-label="Command {index + 1} endpoint"
                      />
                      <EndpointBrowser {bridge} onSelect={(path) => (command.endpoint = path)} />
                    </div>
                    <div>
                      <span class="label py-1"><span class="label-text text-xs">Value</span></span>
                      <input
                        type="number"
                        step="0.01"
                        class="input input-bordered input-sm w-full font-mono"
                        bind:value={command.value}
                        data-testid="sequence-command-value"
                        aria-label="Command {index + 1} value"
                      />
                    </div>
                  </div>
                  <div class="flex-none w-24">
                    <span class="label py-1"><span class="label-text text-xs">Delay (ms)</span></span>
                    <input
                      type="number"
                      min="0"
                      step="50"
                      class="input input-bordered input-sm w-full font-mono"
                      bind:value={command.delay}
                      data-testid="sequence-command-delay"
                      aria-label="Command {index + 1} delay"
                    />
                  </div>
                  <div class="flex-none pt-2 flex flex-col gap-1">
                    <button
                      type="button"
                      class="btn btn-ghost btn-xs btn-circle"
                      title="Move up"
                      disabled={index === 0}
                      onclick={() => moveCommand(index, -1)}
                      data-testid="move-command-up"
                      aria-label="Move command {index + 1} up"
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      class="btn btn-ghost btn-xs btn-circle"
                      title="Move down"
                      disabled={index === editingCommands.length - 1}
                      onclick={() => moveCommand(index, 1)}
                      data-testid="move-command-down"
                      aria-label="Move command {index + 1} down"
                    >
                      ↓
                    </button>
                    <button
                      type="button"
                      class="btn btn-ghost btn-xs btn-circle text-error"
                      title="Remove"
                      onclick={() => removeCommand(index)}
                      data-testid="remove-command"
                      aria-label="Remove command {index + 1}"
                    >
                      ✕
                    </button>
                  </div>
                </div>
              </div>
            {/each}
            <button type="button" class="btn btn-ghost btn-sm w-full" onclick={addCommand} data-testid="add-command">
              + Add Command
            </button>
          </div>
        </div>
        <div class="p-6 border-t border-base-300 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (editing = null)}>Cancel</button>
          <button
            type="button"
            class="btn btn-primary"
            disabled={pending}
            onclick={() => void saveCommands()}
            data-testid="save-commands"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  {/if}

  {#if confirmDelete}
    <div class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="delete-sequence-title">
      <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
        <h2 id="delete-sequence-title" class="text-lg font-semibold">Delete sequence?</h2>
        <p class="mt-3 text-sm">"{confirmDelete.name}" and its commands will be permanently removed.</p>
        <div class="mt-6 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (confirmDelete = null)} data-testid="cancel-delete-sequence">Cancel</button>
          <button
            type="button"
            class="btn btn-error"
            disabled={pending}
            onclick={() => void deleteSequence()}
            data-testid="confirm-delete-sequence"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>
