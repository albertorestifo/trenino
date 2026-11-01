defmodule Trenino.Hardware.I2cInputsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware
  alias Trenino.Hardware.Input

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Chip Device", config_id: 4242})

    {:ok, module} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: %{channel_mask: 0x01, gain: 0}
      })

    {:ok, plain} =
      Hardware.create_input(device.id, %{pin: 1, input_type: :analog, sensitivity: 5})

    chip = Repo.get_by!(Input, i2c_module_id: module.id, i2c_channel: 0)

    {:ok, _matrix} =
      Hardware.create_matrix(device.id, %{name: "M", row_pins: [2, 3], col_pins: [4, 5]})

    for i <- [plain, chip] do
      {:ok, _} =
        Hardware.save_calibration(i.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })
    end

    %{device: device, module: module, plain: plain, chip: chip}
  end

  test "chip input is persisted with its module and channel", %{chip: chip, module: module} do
    assert chip.i2c_module_id == module.id
    assert chip.i2c_channel == 0
  end

  test "channel is unique per module", %{device: device, module: module} do
    assert {:error, cs} =
             Hardware.create_input(device.id, %{
               pin: 201,
               input_type: :analog,
               sensitivity: 5,
               i2c_module_id: module.id,
               i2c_channel: 0
             })

    assert errors_on(cs)[:i2c_module_id] != nil or errors_on(cs)[:i2c_channel] != nil
  end

  test "list_inputs excludes chip inputs by default", %{device: device, chip: chip} do
    {:ok, inputs} = Hardware.list_inputs(device.id)
    refute chip.id in Enum.map(inputs, & &1.id)
  end

  test "list_inputs includes them with include_chip_inputs", %{device: device, chip: chip} do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_chip_inputs: true)
    assert chip.id in Enum.map(inputs, & &1.id)
  end

  test "include_chip_inputs does not include matrix buttons", %{device: device} do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_chip_inputs: true)
    refute Enum.any?(inputs, &(&1.matrix_id != nil))
  end

  test "list_inputs includes chip inputs with include_virtual_buttons", %{
    device: device,
    chip: chip
  } do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)
    assert chip.id in Enum.map(inputs, & &1.id)
  end

  test "list_all_inputs filters the same way", %{chip: chip, plain: plain} do
    default = Enum.map(Hardware.list_all_inputs(), & &1.id)
    assert plain.id in default
    refute chip.id in default

    assert chip.id in Enum.map(Hardware.list_all_inputs(include_chip_inputs: true), & &1.id)

    assert chip.id in Enum.map(
             Hardware.list_all_inputs(include_virtual_buttons: true),
             & &1.id
           )
  end
end

defmodule Trenino.Hardware.I2cInputsLifecycleTest do
  use Trenino.DataCase, async: true

  import Bitwise

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cInputs
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.MCP23017.Params, as: MCPParams
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.ButtonInputBinding
  alias Trenino.Train.LeverInputBinding
  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.Mapping

  @a0 0x0001
  @a1 0x0002
  @b0 0x0100
  @b1 0x0200
  @b2 0x0400

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Chips", config_id: 4343})
    %{device: device}
  end

  defp create_mcp(device, params, extra \\ %{}) do
    Hardware.create_i2c_module(
      device.id,
      Map.merge(
        %{module_chip: :mcp23017, i2c_address: 0x20, params: mcp_params(params)},
        extra
      )
    )
  end

  defp create_ads(device, mask, extra \\ %{}) do
    Hardware.create_i2c_module(
      device.id,
      Map.merge(
        %{module_chip: :ads1115, i2c_address: 0x48, params: %{channel_mask: mask, gain: 0}},
        extra
      )
    )
  end

  defp mcp_params(params), do: Map.merge(%{direct_mask: 0, row_mask: 0, col_mask: 0}, params)

  defp child(%I2cModule{id: id}, channel),
    do: Repo.get_by!(Input, i2c_module_id: id, i2c_channel: channel)

  defp child_channels(%I2cModule{id: id}) do
    Repo.all(
      from i in Input,
        where: i.i2c_module_id == ^id,
        order_by: i.i2c_channel,
        select: i.i2c_channel
    )
  end

  defp cell(row_bit, col_bit), do: 16 + row_bit * 16 + col_bit

  defp calibrate(%Input{id: id}) do
    {:ok, calibration} =
      Hardware.save_calibration(id, %{
        max_hardware_value: 1023,
        min_value: 0,
        max_value: 1000,
        has_rollover: false,
        is_inverted: false
      })

    calibration
  end

  defp train do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Class 66",
        identifiers: [%{identifier: "chips_#{System.unique_integer([:positive])}"}]
      })

    train
  end

  defp bind_lever(train, %Input{id: id}) do
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

    {:ok, config} =
      TrainContext.create_lever_config(element.id, %{
        min_endpoint: "A/Throttle.Min",
        max_endpoint: "A/Throttle.Max",
        value_endpoint: "A/Throttle.Value",
        lever_type: :continuous
      })

    {:ok, binding} = TrainContext.bind_input(config.id, id)
    binding
  end

  defp bind_button(train, %Input{id: id}) do
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

    {:ok, binding} =
      TrainContext.create_button_binding(element.id, id, %{endpoint: "A/Horn.InputValue"})

    binding
  end

  # 128 board-matrix cells fill every virtual pin from 128 to 255.
  defp fill_virtual_pins(device) do
    {:ok, matrix} =
      Hardware.create_matrix(device.id, %{
        name: "Full",
        row_pins: Enum.to_list(0..7),
        col_pins: Enum.to_list(8..23)
      })

    matrix
  end

  describe "allocate/2" do
    test "picks the highest free block" do
      assert I2cInputs.allocate(MapSet.new(), 4) == {:ok, 252}
      assert I2cInputs.allocate(MapSet.new(), 16) == {:ok, 240}
    end

    test "skips used pins" do
      assert I2cInputs.allocate(MapSet.new([255]), 4) == {:ok, 251}
      assert I2cInputs.allocate(MapSet.new(240..255), 4) == {:ok, 236}
    end

    test "can use the lowest virtual pin but never a physical one" do
      assert I2cInputs.allocate(MapSet.new(132..255), 4) == {:ok, 128}
      assert I2cInputs.allocate(MapSet.new(131..255), 4) == :error
    end

    test "returns :error when full" do
      assert I2cInputs.allocate(MapSet.new(128..255), 1) == :error
      assert I2cInputs.allocate(MapSet.new(Enum.take_every(128..255, 4)), 4) == :error
    end
  end

  describe "children/1" do
    test "follows the identity table for an MCP23017" do
      mod = %I2cModule{
        module_chip: :mcp23017,
        params: %MCPParams{
          direct_base: 240,
          matrix_base: 200,
          direct_mask: 0x0208,
          row_mask: @a0 ||| @a1,
          col_mask: @b0 ||| @b2,
          debounce: 2
        }
      }

      assert I2cInputs.children(mod) == [
               %{i2c_channel: 3, pin: 243, input_type: :button, name: "GPA3"},
               %{i2c_channel: 9, pin: 249, input_type: :button, name: "GPB1"},
               %{i2c_channel: cell(0, 8), pin: 200, input_type: :button, name: "R0C0"},
               %{i2c_channel: cell(0, 10), pin: 201, input_type: :button, name: "R0C1"},
               %{i2c_channel: cell(1, 8), pin: 202, input_type: :button, name: "R1C0"},
               %{i2c_channel: cell(1, 10), pin: 203, input_type: :button, name: "R1C1"}
             ]
    end

    test "gives no child to a reference channel", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0101, %{params: params_ref(0b0101, 3)})

      assert [
               %{i2c_channel: 0, pin: 252, input_type: :analog, name: "AIN0"},
               %{i2c_channel: 2, pin: 254, input_type: :analog, name: "AIN2"}
             ] = I2cInputs.children(mod)

      assert child_channels(mod) == [0, 2]
    end

    test "is empty for a display chip" do
      assert I2cInputs.children(%I2cModule{module_chip: :ht16k33}) == []
    end
  end

  defp params_ref(mask, ref), do: %{channel_mask: mask, gain: 0, ref_channel: ref}

  describe "create_i2c_module/2" do
    test "stores both bases and creates one child per channel", %{device: device} do
      assert {:ok, mod} =
               create_mcp(device, %{direct_mask: 0x0003, row_mask: @b0 ||| @b1, col_mask: 0x3000})

      assert mod.params.direct_base == 240
      assert mod.params.matrix_base == 236
      assert length(mod.inputs) == 6
      assert child(mod, 0).name == "GPA0"
      assert child(mod, 1).pin == 241
      assert child(mod, cell(8, 12)).pin == 236
      assert child(mod, cell(9, 13)).pin == 239
      assert child(mod, cell(9, 13)).name == "R1C1"
    end

    test "ignores supplied base values", %{device: device} do
      {:ok, mod} = create_mcp(device, %{direct_mask: 1, direct_base: 130, matrix_base: 140})
      assert mod.params.direct_base == 240
      assert mod.params.matrix_base == 0
    end

    test "an MCP direct block reserves 16 pins", %{device: device} do
      {:ok, mcp} = create_mcp(device, %{direct_mask: @a0})
      {:ok, ads} = create_ads(device, 0b0001)

      assert mcp.params.direct_base == 240
      assert ads.params.pin_base == 236
    end

    test "an ADS block reserves 4 pins", %{device: device} do
      {:ok, ads} = create_ads(device, 0b0001)
      {:ok, mcp} = create_mcp(device, %{direct_mask: @a0})

      assert ads.params.pin_base == 252
      assert mcp.params.direct_base == 236
    end

    test "a chip that does not fit returns an error on :params", %{device: device} do
      fill_virtual_pins(device)

      assert {:error, %Ecto.Changeset{} = cs} = create_ads(device, 0b0001)
      assert errors_on(cs)[:params] != nil
      assert Hardware.list_i2c_modules(device.id) == []
    end

    test "a rejected child rolls the module back", %{device: device} do
      assert {:error, %Ecto.Changeset{} = cs} =
               create_ads(device, 0b0001, %{channels: %{0 => %{sensitivity: 11}}})

      assert errors_on(cs)[:params] != nil
      assert Hardware.list_i2c_modules(device.id) == []
    end

    test "channels name and sensitivity win over defaults", %{device: device} do
      {:ok, mod} =
        create_ads(device, 0b0011, %{channels: %{1 => %{name: "Brake", sensitivity: 8}}})

      assert child(mod, 0).name == "AIN0"
      assert child(mod, 0).sensitivity == 5
      assert child(mod, 1).name == "Brake"
      assert child(mod, 1).sensitivity == 8
    end

    test "accepts string keys, as a form sends them", %{device: device} do
      {:ok, mod} =
        Hardware.create_i2c_module(device.id, %{
          "module_chip" => "ads1115",
          "i2c_address" => "72",
          "params" => %{"channel_mask" => "1", "gain" => "0", "pin_base" => "130"},
          "channels" => %{"0" => %{"name" => "Brake", "sensitivity" => "7"}}
        })

      assert mod.params.pin_base == 252
      assert child(mod, 0).name == "Brake"
      assert child(mod, 0).sensitivity == 7
    end

    test "a display chip still saves with no children", %{device: device} do
      {:ok, mod} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ht16k33,
          i2c_address: 0x70,
          params: %{brightness: 8, num_digits: 4, display_type: :fourteen_segment, has_dot: false}
        })

      assert child_channels(mod) == []
    end
  end

  describe "update_i2c_module/2" do
    test "editing adds and removes only changed channels", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0011)
      kept = child(mod, 1)
      removed = child(mod, 0)
      calibration = calibrate(kept)
      removed_calibration = calibrate(removed)
      binding = bind_lever(train(), kept)

      assert {:ok, updated} =
               Hardware.update_i2c_module(mod, %{params: %{channel_mask: 0b0110, gain: 0}})

      assert child_channels(updated) == [1, 2]
      assert child(updated, 1).id == kept.id
      assert child(updated, 2).sensitivity == 5
      assert Repo.get(Calibration, calibration.id)
      assert Repo.get(LeverInputBinding, binding.id)
      refute Repo.get(Input, removed.id)
      refute Repo.get(Calibration, removed_calibration.id)
    end

    test "reshaping a matrix keeps surviving cells", %{device: device} do
      {:ok, mod} = create_mcp(device, %{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1})
      assert mod.params.matrix_base == 252

      before = for r <- [0, 1], c <- [8, 9], into: %{}, do: {cell(r, c), child(mod, cell(r, c))}
      calibrations = Map.new(before, fn {ch, input} -> {ch, calibrate(input)} end)
      binding = bind_button(train(), before[cell(1, 9)])

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1 ||| @b2})
        })

      assert updated.params.matrix_base == 250
      assert length(child_channels(updated)) == 6

      for r <- [0, 1], c <- [8, 9] do
        input = child(updated, cell(r, c))
        assert input.id == before[cell(r, c)].id
        assert input.pin == 250 + r * 3 + (c - 8)
        assert Repo.get(Calibration, calibrations[cell(r, c)].id)
      end

      assert Repo.get(ButtonInputBinding, binding.id).input_id == before[cell(1, 9)].id
    end

    test "a kept block keeps its base, a block that must grow moves", %{device: device} do
      {:ok, mcp} = create_mcp(device, %{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1})
      {:ok, ads} = create_ads(device, 0b0001)
      assert {mcp.params.matrix_base, ads.params.pin_base} == {252, 248}

      three_by_two = mcp_params(%{row_mask: @a0 ||| @a1 ||| 0x4, col_mask: @b0 ||| @b1})
      {:ok, grown} = Hardware.update_i2c_module(mcp, %{params: three_by_two})
      assert grown.params.matrix_base == 242

      {:ok, renamed} = Hardware.update_i2c_module(grown, %{name: "Panel"})
      assert renamed.params.matrix_base == 242

      one_by_two = mcp_params(%{row_mask: @a0, col_mask: @b0 ||| @b1})
      {:ok, shrunk} = Hardware.update_i2c_module(renamed, %{params: one_by_two})
      assert shrunk.params.matrix_base == 242

      {:ok, reloaded} = Hardware.get_i2c_module(ads.id)
      assert reloaded.params.pin_base == 248
    end

    test "a kept block is not overrun by a sibling block that grows", %{device: device} do
      {:ok, mod} =
        create_mcp(device, %{direct_mask: @a0, row_mask: 0x0C, col_mask: @b0 ||| @b1})

      assert {mod.params.direct_base, mod.params.matrix_base} == {240, 236}

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{direct_mask: @a0, row_mask: 0x1C, col_mask: @b0 ||| @b1 ||| @b2})
        })

      assert updated.params.direct_base == 240
      assert updated.params.matrix_base == 231
    end

    test "a new block does not land on a kept sibling", %{device: device} do
      {:ok, mod} = create_mcp(device, %{row_mask: @a0, col_mask: @b0})
      assert mod.params.matrix_base == 255

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{direct_mask: @a1, row_mask: @a0, col_mask: @b0})
        })

      assert updated.params.matrix_base == 255
      assert updated.params.direct_base == 239
    end

    test "an unused block goes back to base 0", %{device: device} do
      {:ok, mod} =
        create_mcp(device, %{direct_mask: @a0, row_mask: @a1, col_mask: @b0})

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{row_mask: @a1, col_mask: @b0})
        })

      assert updated.params.direct_base == 0
      assert updated.params.matrix_base == mod.params.matrix_base
      assert child_channels(updated) == [cell(1, 8)]
    end

    test "ignores supplied base values", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001)

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: %{channel_mask: 0b0011, gain: 0, pin_base: 130}
        })

      assert updated.params.pin_base == 252
    end

    test "a growth that cannot fit changes nothing", %{device: device} do
      {:ok, _board} =
        Hardware.create_matrix(device.id, %{
          name: "Most",
          row_pins: Enum.to_list(0..6),
          col_pins: Enum.to_list(7..23)
        })

      {:ok, mod} = create_mcp(device, %{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1})
      kept = child(mod, cell(0, 8))

      assert {:error, cs} =
               Hardware.update_i2c_module(mod, %{
                 params: mcp_params(%{row_mask: 0x3F, col_mask: 0x0F00})
               })

      assert errors_on(cs)[:params] != nil
      assert child(mod, cell(0, 8)).pin == kept.pin
      assert length(child_channels(mod)) == 4
    end

    test "button children copy debounce from params", %{device: device} do
      {:ok, mod} = create_mcp(device, %{direct_mask: @a0 ||| @a1, debounce: 4})
      assert child(mod, 0).debounce == 4

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{direct_mask: @a0, debounce: 9})
        })

      assert child(updated, 0).debounce == 9
    end

    test "ADS children keep their sensitivity", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001, %{channels: %{0 => %{sensitivity: 8}}})

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{params: %{channel_mask: 0b0011, gain: 0}})

      assert child(updated, 0).sensitivity == 8

      {:ok, updated} =
        Hardware.update_i2c_module(updated, %{channels: %{0 => %{sensitivity: 3}}})

      assert child(updated, 0).sensitivity == 3
    end

    test "kept children keep their name unless channels supplies one", %{device: device} do
      {:ok, mod} = create_mcp(device, %{row_mask: @a1, col_mask: @b0 ||| @b1})
      assert child(mod, cell(1, 9)).name == "R0C1"

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1})
        })

      assert child(updated, cell(1, 9)).name == "R0C1"
      assert child(updated, cell(0, 8)).name == "R0C0"

      {:ok, updated} =
        Hardware.update_i2c_module(updated, %{
          channels: %{cell(1, 9) => %{name: "Horn"}}
        })

      assert child(updated, cell(1, 9)).name == "Horn"
    end
  end

  describe "params must match the chip" do
    test "an edit cannot store another chip's params", %{device: device} do
      {:ok, mcp} = create_mcp(device, %{direct_mask: @a0})

      assert {:error, cs} =
               Hardware.update_i2c_module(mcp, %{params: %{channel_mask: 1, gain: 0}})

      assert errors_on(cs)[:params] == ["do not match this chip"]
      {:ok, reloaded} = Hardware.get_i2c_module(mcp.id)
      assert %MCPParams{} = reloaded.params
      assert child_channels(mcp) == [0]
    end

    test "a create cannot pair a chip with another chip's params", %{device: device} do
      assert {:error, cs} =
               Hardware.create_i2c_module(device.id, %{
                 module_chip: :mcp23017,
                 i2c_address: 0x20,
                 params: %{
                   brightness: 8,
                   num_digits: 4,
                   display_type: :fourteen_segment,
                   has_dot: false
                 }
               })

      assert errors_on(cs)[:params] == ["do not match this chip"]
    end

    test "partial params edit the chip they belong to", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001)

      assert {:ok, updated} = Hardware.update_i2c_module(mod, %{params: %{gain: 1}})
      assert updated.params.gain == 1
      assert updated.params.channel_mask == 0b0001
    end

    test "partial params give a changeset on create", %{device: device} do
      assert {:error, %Ecto.Changeset{}} =
               Hardware.create_i2c_module(device.id, %{
                 module_chip: :ads1115,
                 i2c_address: 0x48,
                 params: %{gain: 0}
               })
    end

    test "params with no chip give a changeset", %{device: device} do
      assert {:error, %Ecto.Changeset{}} =
               Hardware.create_i2c_module(device.id, %{i2c_address: 0x48, params: %{gain: 0}})
    end
  end

  describe "stale and moved modules" do
    test "a stale struct does not delete real children", %{device: device} do
      {:ok, stale} = create_ads(device, 0b0001)

      {:ok, _fresh} =
        Hardware.update_i2c_module(stale, %{params: %{channel_mask: 0b0011, gain: 0}})

      assert {:ok, renamed} = Hardware.update_i2c_module(stale, %{name: "Renamed"})

      assert renamed.name == "Renamed"
      assert renamed.params.channel_mask == 0b0011
      assert child_channels(renamed) == [0, 1]
    end

    test "a stale struct does not move a block off its row's base", %{device: device} do
      {:ok, ads} = create_ads(device, 0b0001)
      {:ok, mcp} = create_mcp(device, %{row_mask: @a0, col_mask: @b0})
      assert mcp.params.matrix_base == 251
      {:ok, _} = Hardware.delete_i2c_module(ads)

      stale = %{mcp | params: %{mcp.params | matrix_base: 255}}

      {:ok, updated} =
        Hardware.update_i2c_module(stale, %{
          params: mcp_params(%{row_mask: @a0 ||| @a1, col_mask: @b0})
        })

      assert updated.params.matrix_base == 251
    end

    test "device_id cannot change on update", %{device: device} do
      {:ok, other} = Hardware.create_device(%{name: "Other", config_id: 4344})
      {:ok, mod} = create_ads(device, 0b0001)

      assert {:error, cs} = Hardware.update_i2c_module(mod, %{device_id: other.id})
      assert errors_on(cs)[:device_id] == ["cannot be changed after creation"]
      assert [%I2cModule{}] = Hardware.list_i2c_modules(device.id)
    end

    test "a base below 128 is not kept", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001)

      mod =
        mod
        |> Ecto.Changeset.change(params: %{mod.params | pin_base: 100})
        |> Repo.update!()

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{params: %{channel_mask: 0b0011, gain: 0}})

      assert updated.params.pin_base == 252
    end

    test "adding a lower column with base kept shifts pins onto siblings", %{device: device} do
      {mod, inputs} = two_by_two_below_free_pins(device)

      {:ok, updated} =
        Hardware.update_i2c_module(mod, %{
          params: mcp_params(%{row_mask: @a0 ||| @a1, col_mask: @b0 ||| @b1 ||| @b2})
        })

      assert updated.params.matrix_base == 248

      for {r, c, col_index} <- [{0, 9, 1}, {0, 10, 2}, {1, 9, 1}, {1, 10, 2}] do
        input = child(updated, cell(r, c))
        assert input.id == inputs[cell(r, c)].id
        assert input.pin == 248 + r * 3 + col_index
      end

      assert child(updated, cell(0, 8)).pin == 248
      assert child(updated, cell(1, 8)).pin == 251
    end

    test "a failed edit rolls moved rows back", %{device: device} do
      {:ok, matrix} =
        Hardware.create_matrix(device.id, %{name: "M", row_pins: [0], col_pins: [1]})

      {:ok, mod} = create_ads(device, 0b1000)
      kept = child(mod, 3)

      # A row the allocator must avoid, standing in the chip's block.
      Repo.insert!(%Input{
        device_id: device.id,
        matrix_id: matrix.id,
        pin: 252,
        input_type: :button,
        debounce: 1
      })

      assert {:error, cs} =
               Hardware.update_i2c_module(mod, %{
                 params: %{channel_mask: 0b1001, gain: 0},
                 channels: %{3 => %{sensitivity: 11}}
               })

      assert errors_on(cs)[:params] != nil
      assert child(mod, 3).pin == kept.pin
      assert child_channels(mod) == [3]
      {:ok, reloaded} = Hardware.get_i2c_module(mod.id)
      assert reloaded.params.pin_base == 252
    end

    defp two_by_two_below_free_pins(device) do
      {:ok, ads} = create_ads(device, 0b0001)

      {:ok, mod} =
        create_mcp(device, %{row_mask: @a0 ||| @a1, col_mask: @b1 ||| @b2})

      assert mod.params.matrix_base == 248
      {:ok, _} = Hardware.delete_i2c_module(ads)

      channels = for r <- [0, 1], c <- [9, 10], do: cell(r, c)
      {mod, Map.new(channels, &{&1, child(mod, &1)})}
    end
  end

  describe "malformed channels" do
    test "a non-integer key returns an error on :params", %{device: device} do
      assert {:error, cs} = create_ads(device, 0b0001, %{channels: %{"abc" => %{name: "X"}}})
      assert errors_on(cs)[:params] != nil
      assert Hardware.list_i2c_modules(device.id) == []

      assert {:error, _} = create_ads(device, 0b0001, %{channels: %{1.5 => %{name: "X"}}})
    end

    test "non-map settings return an error on :params", %{device: device} do
      assert {:error, cs} = create_ads(device, 0b0001, %{channels: %{0 => "Brake"}})
      assert errors_on(cs)[:params] != nil
    end

    test "a non-map channels value returns an error on :params", %{device: device} do
      assert {:error, cs} = create_ads(device, 0b0001, %{channels: [1, 2]})
      assert errors_on(cs)[:params] != nil
    end
  end

  describe "delete_i2c_module/1" do
    test "removes children, calibrations and bindings", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0011)
      first = child(mod, 0)
      calibration = calibrate(first)
      lever = bind_lever(train(), first)

      {:ok, mcp} = create_mcp(device, %{direct_mask: @a0 ||| @a1})
      button = bind_button(train(), child(mcp, 0))

      {:ok, mapping} =
        VirtualJoystick.put_mapping(child(mod, 1).id, %{target_type: :axis, axis: :x})

      assert {:ok, _} = Hardware.delete_i2c_module(mod)
      assert {:ok, _} = Hardware.delete_i2c_module(mcp)

      refute Repo.get(I2cModule, mod.id)
      assert child_channels(mod) == []
      refute Repo.get(Calibration, calibration.id)
      refute Repo.get(LeverInputBinding, lever.id)
      refute Repo.get(ButtonInputBinding, button.id)
      refute Repo.get(Mapping, mapping.id)
    end
  end

  describe "delete_device/1" do
    test "removes chips after their inputs", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001)
      calibration = calibrate(child(mod, 0))

      assert {:ok, _} = Hardware.delete_device(device)

      refute Repo.get(I2cModule, mod.id)
      assert child_channels(mod) == []
      refute Repo.get(Calibration, calibration.id)
    end
  end

  describe "i2c_module_impact/2" do
    setup %{device: device} do
      {:ok, mod} = create_ads(device, 0b0111)
      {:ok, mcp} = create_mcp(device, %{direct_mask: @a0})
      %{mod: mod, mcp: mcp}
    end

    test "names lever, button and joystick bindings", %{mod: mod, mcp: mcp} do
      train = train()
      bind_lever(train, child(mod, 0))
      bind_button(train, child(mcp, 0))
      {:ok, _} = VirtualJoystick.put_mapping(child(mod, 1).id, %{target_type: :axis, axis: :x})

      assert [
               %{name: "AIN0", binding: lever, input_id: lever_input},
               %{name: "AIN1", binding: joystick, input_id: joystick_input}
             ] = Hardware.i2c_module_impact(mod)

      assert lever_input == child(mod, 0).id
      assert joystick_input == child(mod, 1).id
      assert lever =~ "Throttle"
      assert lever =~ "Class 66"
      assert joystick =~ "joystick"

      assert [%{name: "GPA0", binding: button}] = Hardware.i2c_module_impact(mcp)
      assert button =~ "Horn"
    end

    test "with attrs lists only what the edit removes", %{mod: mod} do
      train = train()
      bind_lever(train, child(mod, 2))
      {:ok, _} = VirtualJoystick.put_mapping(child(mod, 1).id, %{target_type: :axis, axis: :x})

      assert [%{name: "AIN1"}] =
               Hardware.i2c_module_impact(mod, %{params: %{channel_mask: 0b0101, gain: 0}})

      assert Hardware.i2c_module_impact(mod, %{name: "Renamed"}) == []
    end

    test "is empty when the edit is invalid", %{mod: mod} do
      {:ok, _} = VirtualJoystick.put_mapping(child(mod, 1).id, %{target_type: :axis, axis: :x})

      assert Hardware.i2c_module_impact(mod, %{params: %{channel_mask: 0, gain: 0}}) == []
    end

    test "does not change anything", %{mod: mod} do
      bind_lever(train(), child(mod, 0))

      assert [_] = Hardware.i2c_module_impact(mod, %{params: %{channel_mask: 0b0110, gain: 0}})
      assert child_channels(mod) == [0, 1, 2]
    end
  end

  describe "board matrix against chip blocks" do
    test "matrix overlapping a chip block returns a changeset error", %{device: device} do
      {:ok, mod} = create_ads(device, 0b0001)

      assert {:error, %Ecto.Changeset{}} =
               Hardware.create_matrix(device.id, %{
                 name: "Too big",
                 row_pins: Enum.to_list(0..7),
                 col_pins: Enum.to_list(8..23)
               })

      assert child(mod, 0).pin == 252
    end

    test "matrix reaching a reserved pin with no child is also refused", %{device: device} do
      {:ok, mod} = create_ads(device, 0b1000)
      assert child(mod, 3).pin == 255

      # 125 cells end on pin 252, inside the block but below its only child.
      assert {:error, %Ecto.Changeset{} = cs} =
               Hardware.create_matrix(device.id, %{
                 name: "Reserved",
                 row_pins: Enum.to_list(0..4),
                 col_pins: Enum.to_list(5..29)
               })

      assert errors_on(cs)[:row_pins] != nil
    end

    test "update_matrix honours the same limit", %{device: device} do
      {:ok, _} = create_ads(device, 0b1000)

      {:ok, matrix} =
        Hardware.create_matrix(device.id, %{name: "Small", row_pins: [0], col_pins: [1]})

      assert {:error, %Ecto.Changeset{}} =
               Hardware.update_matrix(matrix, %{
                 row_pins: Enum.to_list(0..4),
                 col_pins: Enum.to_list(5..29)
               })
    end
  end
end
