defmodule Trenino.MCP.Tools.ElementToolsTest do
  use Trenino.DataCase, async: false

  alias Trenino.MCP.Tools.ElementTools
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "BR 146.2", identifier: "br146"})
    %{train: train}
  end

  describe "list_elements" do
    test "returns empty list when no elements", %{train: train} do
      assert {:ok, %{elements: []}} =
               ElementTools.execute("list_elements", %{"train_id" => train.id})
    end

    test "returns all elements for a train", %{train: train} do
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:ok, %{elements: elements}} =
               ElementTools.execute("list_elements", %{"train_id" => train.id})

      assert length(elements) == 2

      names = Enum.map(elements, & &1.name)
      assert "Horn" in names
      assert "Throttle" in names
    end

    test "returns element fields", %{train: train} do
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      {:ok, %{elements: [result]}} =
        ElementTools.execute("list_elements", %{"train_id" => train.id})

      assert result.id == element.id
      assert result.name == "Horn"
      assert result.type == :button
    end

    test "does not return elements from other trains", %{train: train} do
      {:ok, other_train} = TrainContext.create_train(%{name: "Class 66", identifier: "class66"})
      {:ok, _} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, _} = TrainContext.create_element(other_train.id, %{name: "Brake", type: :lever})

      assert {:ok, %{elements: elements}} =
               ElementTools.execute("list_elements", %{"train_id" => train.id})

      assert length(elements) == 1
      assert hd(elements).name == "Horn"
    end
  end

  describe "create_element" do
    test "creates a button element", %{train: train} do
      args = %{"train_id" => train.id, "name" => "Horn Hi", "type" => "button"}

      assert {:ok, %{element: element}} = ElementTools.execute("create_element", args)

      assert element.name == "Horn Hi"
      assert element.type == :button
      assert is_integer(element.id)
    end

    test "creates a lever element", %{train: train} do
      args = %{"train_id" => train.id, "name" => "Throttle", "type" => "lever"}

      assert {:ok, %{element: element}} = ElementTools.execute("create_element", args)

      assert element.name == "Throttle"
      assert element.type == :lever
    end

    test "returns error for missing name", %{train: train} do
      args = %{"train_id" => train.id, "name" => "", "type" => "button"}

      assert {:error, message} = ElementTools.execute("create_element", args)
      assert message =~ "Validation failed"
    end

    test "returns error for invalid type", %{train: train} do
      args = %{"train_id" => train.id, "name" => "Horn", "type" => "invalid"}

      assert {:error, message} = ElementTools.execute("create_element", args)
      assert message =~ "Validation failed"
    end
  end

  describe "delete_element" do
    test "deletes an existing element", %{train: train} do
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      assert {:ok, %{deleted: true, id: id}} =
               ElementTools.execute("delete_element", %{"id" => element.id})

      assert id == element.id
      assert {:error, :not_found} = TrainContext.get_element(element.id)
    end

    test "returns error for non-existent element" do
      assert {:error, message} = ElementTools.execute("delete_element", %{"id" => -1})
      assert message =~ "not found"
    end
  end
end
