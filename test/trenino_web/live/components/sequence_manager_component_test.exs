defmodule TreninoWeb.SequenceManagerComponentTest do
  use TreninoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias Trenino.Simulator.Client
  alias Trenino.Train, as: TrainContext
  alias TreninoWeb.SequenceManagerComponent

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    # Create a train with sequences and commands
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Test Train",
        identifier: "Test_Train_SeqMgr_#{System.unique_integer([:positive])}"
      })

    # Create a sequence with some commands
    {:ok, sequence1} =
      TrainContext.create_sequence(train.id, %{
        name: "Horn Sequence"
      })

    {:ok, _commands} =
      TrainContext.set_sequence_commands(sequence1, [
        %{endpoint: "CurrentDrivableActor/Horn.InputValue", value: 1.0, delay_ms: 500},
        %{endpoint: "CurrentDrivableActor/Horn.InputValue", value: 0.0, delay_ms: 0}
      ])

    # Create another sequence without commands
    {:ok, _sequence2} =
      TrainContext.create_sequence(train.id, %{
        name: "Door Open"
      })

    # Create a mock client
    client = Client.new("http://localhost:8080", "test-key")

    # Reload sequences with commands
    sequences = TrainContext.list_sequences(train.id)

    %{
      train: train,
      sequences: sequences,
      sequence1: Enum.find(sequences, &(&1.name == "Horn Sequence")),
      sequence2: Enum.find(sequences, &(&1.name == "Door Open")),
      client: client
    }
  end

  describe "basic rendering" do
    test "renders sequences list", %{train: train, sequences: sequences, client: client} do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      assert html =~ "Sequences"
      assert html =~ "Horn Sequence"
      assert html =~ "Door Open"
      assert html =~ "2 commands"
      assert html =~ "0 commands"
    end

    test "shows empty state when no sequences", %{train: train, client: client} do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: [],
          client: client
        )

      assert html =~ "No sequences defined"
      assert html =~ "Execute multiple commands from a single button press"
    end

    test "shows edit button for each sequence", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      assert html =~ "phx-click=\"edit_sequence\""
      assert html =~ "hero-pencil"
    end

    test "shows delete button for each sequence", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      assert html =~ "phx-click=\"delete_sequence\""
      assert html =~ "hero-trash"
    end

    test "shows test button for sequences with commands", %{
      train: train,
      sequences: sequences,
      sequence1: sequence1,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Test button should be present for sequence with commands
      assert html =~ "phx-click=\"test_sequence\""
      assert html =~ "phx-value-id=\"#{sequence1.id}\""
      assert html =~ "title=\"Test sequence\""
    end

    test "disables test button for sequences without commands", %{
      train: train,
      sequences: sequences,
      sequence2: sequence2,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Find the test button for sequence2 - it should be disabled
      # Look for the pattern: phx-value-id matching sequence2.id followed by disabled attribute
      assert html =~ ~r/phx-value-id="#{sequence2.id}"[^>]*disabled/
    end

    test "shows new sequence button", %{train: train, sequences: sequences, client: client} do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      assert html =~ "phx-click=\"open_add_modal\""
      assert html =~ "New Sequence"
    end
  end

  describe "command count display" do
    test "shows correct command count for sequence with multiple commands", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Horn Sequence has 2 commands
      assert html =~ "2 commands"
    end

    test "shows correct command count for sequence with no commands", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Door Open has 0 commands
      assert html =~ "0 commands"
    end

    test "shows singular 'command' for sequence with one command", %{
      train: train,
      client: client
    } do
      # Create a sequence with exactly one command
      {:ok, single_seq} =
        TrainContext.create_sequence(train.id, %{
          name: "Single Command"
        })

      {:ok, _} =
        TrainContext.set_sequence_commands(single_seq, [
          %{endpoint: "Test.InputValue", value: 1.0, delay_ms: 0}
        ])

      sequences = TrainContext.list_sequences(train.id)

      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Should show "1 command" (singular) not "1 commands"
      assert html =~ "1 command"
      refute html =~ "1 commands"
    end
  end

  describe "sequence ordering" do
    test "displays sequences in the order provided", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # The sequences are ordered by name from list_sequences
      # Door Open comes before Horn Sequence alphabetically
      door_open_pos = String.split(html, "Door Open") |> List.first() |> String.length()
      horn_seq_pos = String.split(html, "Horn Sequence") |> List.first() |> String.length()

      assert door_open_pos < horn_seq_pos
    end
  end

  describe "client handling" do
    test "renders without client (client can be nil)", %{train: train, sequences: sequences} do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: nil
        )

      # Should still render the basic list
      assert html =~ "Sequences"
      assert html =~ "Horn Sequence"
    end

    test "passes client to child components when available", %{
      train: train,
      sequences: sequences,
      client: client
    } do
      html =
        render_component(SequenceManagerComponent,
          id: "sequence-manager",
          train_id: train.id,
          sequences: sequences,
          client: client
        )

      # Component should render successfully with client
      assert html =~ "Sequences"
    end
  end
end
