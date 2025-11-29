defmodule TswIo.TrainTest do
  use TswIo.DataCase, async: true

  alias TswIo.Train, as: TrainContext
  alias TswIo.Train.{Train, Element, LeverConfig, Notch}

  describe "create_train/1" do
    test "creates a train with valid attributes" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66", description: "Freight locomotive"}

      assert {:ok, %Train{} = train} = TrainContext.create_train(attrs)
      assert train.name == "Class 66"
      assert train.identifier == "BR_Class_66"
      assert train.description == "Freight locomotive"
    end

    test "creates a train without description" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66"}

      assert {:ok, %Train{} = train} = TrainContext.create_train(attrs)
      assert train.description == nil
    end

    test "returns error changeset with missing name" do
      attrs = %{identifier: "BR_Class_66"}

      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset with missing identifier" do
      attrs = %{name: "Class 66"}

      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{identifier: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique identifier" do
      attrs = %{name: "Class 66", identifier: "BR_Class_66"}

      assert {:ok, _train} = TrainContext.create_train(attrs)
      assert {:error, changeset} = TrainContext.create_train(attrs)
      assert %{identifier: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_train/2" do
    test "returns train by id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = found} = TrainContext.get_train(train.id)
      assert found.id == train.id
      assert found.name == "Class 66"
    end

    test "returns error when train not found" do
      assert {:error, :not_found} = TrainContext.get_train(999_999)
    end

    test "preloads associations when requested" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, found} = TrainContext.get_train(train.id, preload: [:elements])

      assert length(found.elements) == 1
    end
  end

  describe "get_train_by_identifier/1" do
    test "returns train with matching identifier" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = found} = TrainContext.get_train_by_identifier("BR_Class_66")
      assert found.id == train.id
    end

    test "returns error when no train matches identifier" do
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("NonExistent")
    end

    test "preloads elements with lever_config" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, _config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, found} = TrainContext.get_train_by_identifier("BR_Class_66")

      assert length(found.elements) == 1
      assert hd(found.elements).lever_config != nil
    end
  end

  describe "update_train/2" do
    test "updates train with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Original", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = updated} = TrainContext.update_train(train, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "updates description" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{} = updated} =
               TrainContext.update_train(train, %{description: "New description"})

      assert updated.description == "New description"
    end
  end

  describe "delete_train/1" do
    test "deletes train" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, %Train{}} = TrainContext.delete_train(train)
      assert {:error, :not_found} = TrainContext.get_train(train.id)
    end

    test "cascade deletes associated elements" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, _} = TrainContext.delete_train(train)
      assert {:ok, []} = TrainContext.list_elements(train.id)
    end
  end

  describe "list_trains/1" do
    test "returns empty list when no trains exist" do
      assert [] = TrainContext.list_trains()
    end

    test "returns trains ordered by name" do
      {:ok, _} = TrainContext.create_train(%{name: "Zebra", identifier: "id1"})
      {:ok, _} = TrainContext.create_train(%{name: "Alpha", identifier: "id2"})
      {:ok, _} = TrainContext.create_train(%{name: "Beta", identifier: "id3"})

      trains = TrainContext.list_trains()
      names = Enum.map(trains, & &1.name)

      assert names == ["Alpha", "Beta", "Zebra"]
    end

    test "preloads associations when requested" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      [found] = TrainContext.list_trains(preload: [:elements])

      assert length(found.elements) == 1
    end
  end

  describe "create_element/2" do
    test "creates element with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Throttle", type: :lever}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.train_id == train.id
      assert element.name == "Throttle"
      assert element.type == :lever
    end

    test "accepts string type" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      attrs = %{name: "Throttle", type: "lever"}

      assert {:ok, %Element{} = element} = TrainContext.create_element(train.id, attrs)
      assert element.type == :lever
    end

    test "returns error changeset with missing name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:error, changeset} = TrainContext.create_element(train.id, %{type: :lever})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset with missing type" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:error, changeset} = TrainContext.create_element(train.id, %{name: "Throttle"})
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_elements/1" do
    test "returns empty list when no elements exist" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      assert {:ok, []} = TrainContext.list_elements(train.id)
    end

    test "returns elements ordered by name" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})

      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Brake", type: :lever})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Reverser", type: :lever})

      {:ok, elements} = TrainContext.list_elements(train.id)
      names = Enum.map(elements, & &1.name)

      assert names == ["Brake", "Reverser", "Throttle"]
    end

    test "preloads lever_config with notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, _config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, [found]} = TrainContext.list_elements(train.id)

      assert found.lever_config != nil
      assert found.lever_config.notches == []
    end
  end

  describe "get_element/2" do
    test "returns element by id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %Element{} = found} = TrainContext.get_element(element.id)
      assert found.id == element.id
    end

    test "returns error when element not found" do
      assert {:error, :not_found} = TrainContext.get_element(999_999)
    end
  end

  describe "delete_element/1" do
    test "deletes element" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %Element{}} = TrainContext.delete_element(element)
      assert {:error, :not_found} = TrainContext.get_element(element.id)
    end
  end

  describe "create_lever_config/2" do
    test "creates lever config with valid attributes" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      attrs = %{
        min_endpoint: "CurrentDrivableActor/Throttle.MinValue",
        max_endpoint: "CurrentDrivableActor/Throttle.MaxValue",
        value_endpoint: "CurrentDrivableActor/Throttle.InputValue"
      }

      assert {:ok, %LeverConfig{} = config} = TrainContext.create_lever_config(element.id, attrs)
      assert config.element_id == element.id
      assert config.min_endpoint == "CurrentDrivableActor/Throttle.MinValue"
      assert config.calibrated_at == nil
    end

    test "returns error changeset with missing required fields" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:error, changeset} = TrainContext.create_lever_config(element.id, %{})

      errors = errors_on(changeset)
      assert %{min_endpoint: ["can't be blank"]} = errors
      assert %{max_endpoint: ["can't be blank"]} = errors
      assert %{value_endpoint: ["can't be blank"]} = errors
    end
  end

  describe "get_lever_config/1" do
    test "returns lever config by element id" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      assert {:ok, %LeverConfig{} = found} = TrainContext.get_lever_config(element.id)
      assert found.id == config.id
    end

    test "returns error when no config exists" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:error, :not_found} = TrainContext.get_lever_config(element.id)
    end

    test "preloads notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, _} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 1.0}
        ])

      {:ok, found} = TrainContext.get_lever_config(element.id)

      assert length(found.notches) == 2
    end
  end

  describe "save_calibration/2" do
    test "saves notches and sets calibrated_at" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      notches = [
        %{type: :gate, value: 0.0, description: "Off"},
        %{type: :linear, value: 0.5, min_value: 0.0, max_value: 1.0},
        %{type: :gate, value: 1.0, description: "Full"}
      ]

      assert {:ok, %LeverConfig{} = updated} = TrainContext.save_calibration(config, notches)
      assert updated.calibrated_at != nil
      assert length(updated.notches) == 3

      [first, second, third] = Enum.sort_by(updated.notches, & &1.index)
      assert first.type == :gate
      assert first.value == 0.0
      assert first.description == "Off"
      assert first.index == 0

      assert second.type == :linear
      assert second.value == 0.5
      assert second.min_value == 0.0
      assert second.max_value == 1.0
      assert second.index == 1

      assert third.type == :gate
      assert third.value == 1.0
      assert third.description == "Full"
      assert third.index == 2
    end

    test "replaces existing notches" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      # First calibration
      {:ok, _} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 1.0}
        ])

      # Second calibration should replace
      {:ok, updated} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0},
          %{type: :gate, value: 0.5},
          %{type: :gate, value: 1.0}
        ])

      assert length(updated.notches) == 3
    end
  end

  describe "update_notch_description/2" do
    test "updates notch description" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, saved} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0}
        ])

      notch = hd(saved.notches)

      assert {:ok, %Notch{} = updated} =
               TrainContext.update_notch_description(notch, "Idle Position")

      assert updated.description == "Idle Position"
    end

    test "clears notch description with nil" do
      {:ok, train} = TrainContext.create_train(%{name: "Class 66", identifier: "BR_Class_66"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "Min",
          max_endpoint: "Max",
          value_endpoint: "Value"
        })

      {:ok, saved} =
        TrainContext.save_calibration(config, [
          %{type: :gate, value: 0.0, description: "Old"}
        ])

      notch = hd(saved.notches)

      assert {:ok, %Notch{} = updated} = TrainContext.update_notch_description(notch, nil)
      assert updated.description == nil
    end
  end
end
