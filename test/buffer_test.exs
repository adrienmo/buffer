defmodule BufferTest do
  use ExUnit.Case

  setup_all do
    Buffer.Supervisor.start_child(BufferKeyListResult)
    Buffer.Supervisor.start_child(BufferKeyListLimit)
    Buffer.Supervisor.start_child(BufferKeyListInterval)
    Buffer.Supervisor.start_child(BufferCount)
    Buffer.Supervisor.start_child(BufferRead)
    Buffer.Supervisor.start_child(BufferReadUpdate)
    Buffer.Supervisor.start_child(BufferReadUpdateCustom)
    Buffer.Supervisor.start_child(BufferReadDefaultBehavior)
    Buffer.Supervisor.start_child(BufferReadDeleteBehavior)
    Buffer.Supervisor.start_child(BufferSync)
    Buffer.Supervisor.start_child(BufferReadTimeout)
    :ets.new(:read_nil, [:named_table, :public])
    Buffer.Supervisor.start_child(BufferReadNil)
    :ok
  end

  setup do
    BufferKeyListResult.reset()
    {:ok, []}
  end

  test "0000# Write, KeyList, Limit + Sync" do
    for x <- 1..4, do: BufferKeyListLimit.add(1, x)
    for x <- 1..25, do: BufferKeyListLimit.add(2, x)

    result = BufferKeyListResult.dump_table()
    result = Enum.map(result, fn({_, [{2, x}]}) -> x end)
    assert(result == [Enum.map(1..10, &(&1)), Enum.map(11..20, &(&1))])

    BufferKeyListResult.reset()
    BufferKeyListLimit.sync()

    result = BufferKeyListResult.dump_table()
    result = Enum.map(result, fn({_, x}) -> x end) |> hd()
    assert(result == [{1,Enum.map(1..4, &(&1))}, {2,Enum.map(21..25, &(&1))}])
  end

  test "0001# Write, KeyList, Interval" do
    1..4 |> Enum.map(&(BufferKeyListInterval.add(1, &1)))

    result = BufferKeyListResult.dump_table()
    assert([] == result)

    :timer.sleep(1000)

    result = BufferKeyListResult.dump_table()
    assert([{_, [{1, [1, 2, 3, 4]}]}] = result)
  end

  test "0010# Read, Count, Sync" do
    for _ <- 1..100, do: BufferCount.incr(:key1)
    for x <- 1..100, do: BufferCount.incr(:key2, x)

    assert([key2: 5050, key1: 100] == BufferCount.dump_table())
    BufferCount.sync()
    result = BufferKeyListResult.dump_table()
    assert([{_, [key2: 5050, key1: 100]}] = result)
    BufferCount.reset()
  end

  test "0100# Read, Get" do
    BufferRead.sync()
    assert(BufferRead.get(:key1) == "value1")
  end

  test "0101# Read, Select" do
    BufferRead.sync()
    match_spec1 = get_match_spec("fn(x = {_, %{field1: 5}}) -> x end")
    match_spec2 = get_match_spec("fn(x = {_, %{field2: 4}}) -> x end")

    field1_5 = BufferRead.select(match_spec1)
    field2_4 = BufferRead.select(match_spec2)
    {field2_4_1, _} = BufferRead.select(match_spec2, 1)

    assert(field1_5[:key3] != nil)
    assert(field2_4[:key3] != nil)
    assert(field2_4[:key4] != nil)
    assert(length(field2_4_1) == 1)
  end

  test "0102# Read, Update" do
    BufferKeyListResult.add(:key1, :value1)
    BufferKeyListResult.add(:key2, :value2)

    BufferReadUpdate.sync()
    BufferKeyListResult.reset()

    BufferKeyListResult.add(:key1, :value2)
    BufferKeyListResult.add(:key2, :value2)

    BufferReadUpdate.sync()
    result = BufferKeyListResult.dump_table()
    assert(result[BufferReadUpdate] == [:key1])
  end

  test "0103# Read, Delete" do
    BufferReadDefaultBehavior.reset()
    BufferReadDeleteBehavior.reset()

    BufferKeyListResult.add(:key1, :value1)
    BufferKeyListResult.add(:key2, :value2)

    BufferReadDefaultBehavior.sync()
    BufferReadDeleteBehavior.sync()

    BufferKeyListResult.reset()
    BufferKeyListResult.add(:key3, :value3)

    BufferReadDefaultBehavior.sync()
    BufferReadDeleteBehavior.sync()

    assert(length(BufferReadDefaultBehavior.dump_table()) == 3)
    assert(length(BufferReadDeleteBehavior.dump_table()) == 1)
  end

  test "0104# Read, Update, Custom Update function" do
    BufferKeyListResult.add(:key1, %{val: 1, key: 1})
    BufferKeyListResult.add(:key2, %{val: 2, key: 2})

    BufferReadUpdateCustom.sync()
    BufferKeyListResult.reset()

    BufferKeyListResult.add(:key1, %{val: 3, key: 1})
    BufferKeyListResult.add(:key2, %{val: 4, key: 3})

    BufferReadUpdateCustom.sync()
    result = BufferKeyListResult.dump_table()
    assert(result[BufferReadUpdateCustom] == [:key2])
  end

  test "0105# Read, Get with timeout" do
    Process.sleep(7_000)
    assert(BufferReadTimeout.get(:key1) == "value1")
  end

  test "0106# Reload read if nil" do
    assert(BufferReadNil.get(:value) == nil)
    :ets.delete(:read_nil, "read_nil")
    :ets.insert(:read_nil, {"read_nil", {:value, "hello"}})
    assert(BufferReadNil.get(:value) == "hello")
  end

  test "0200# Sync" do
    BufferSync.add(1)
    BufferSync.add(5)
    BufferSync.sync

    assert [{1, 2}, {5, 10}] == BufferKeyListResult.dump_table()

    BufferKeyListResult.reset()
    BufferSync.delete(5)
    BufferSync.sync

    assert [{1, 2}] == BufferKeyListResult.dump_table()

    BufferKeyListResult.reset()
    BufferSync.add(2)
    BufferSync.reset
    BufferSync.sync

    assert [] == BufferKeyListResult.dump_table()
  end

  defp get_match_spec(fun_string) do
    fun_string
    |> Code.eval_string()
    |> elem(0)
    |> :ets.fun2ms()
  end
end

defmodule BufferKeyListResult do
  use Buffer.Write.KeyList
  def write(_), do: nil
end

defmodule BufferKeyListLimit do
  use Buffer.Write.KeyList, limit: 10
  def write(keylists), do: BufferKeyListResult.add(__MODULE__, keylists)
end

defmodule BufferKeyListInterval do
  use Buffer.Write.KeyList, interval: 1000, limit: nil
  def write(keylists), do: BufferKeyListResult.add(__MODULE__, keylists)
end

defmodule BufferCount do
  use Buffer.Write.Count
  def write(counters), do: BufferKeyListResult.add(__MODULE__, counters)
end

defmodule BufferRead do
  use Buffer.Read
  def read do
    [
      {:key1, "value1"},
      {:key2, "value2"},
      {:key3, %{field1: 5, field2: 4}},
      {:key4, %{field1: 4, field2: 4}}
    ]
  end
end

defmodule BufferReadTimeout do
  use Buffer.Read, timeout: 8_000
  def read do
    Process.sleep(6_000)
    [
      {:key1, "value1"},
      {:key2, "value2"},
      {:key3, %{field1: 5, field2: 4}},
      {:key4, %{field1: 4, field2: 4}}
    ]
  end
end

defmodule BufferReadUpdate do
  use Buffer.Read
  def read, do: BufferKeyListResult.dump_table
  def on_element_updated(x), do: BufferKeyListResult.add(__MODULE__, x)
end

defmodule BufferReadUpdateCustom do
  use Buffer.Read
  def read, do: BufferKeyListResult.dump_table
  def on_element_updated(x), do: BufferKeyListResult.add(__MODULE__, x)
  def updated?(el1, el2) do
    if is_nil(el1) or is_nil(el2) do
      el1 != el2
    else
      el1[:key] != el2[:key]
    end
  end
end

defmodule BufferReadDefaultBehavior do
  use Buffer.Read
  def read, do: BufferKeyListResult.dump_table
end

defmodule BufferReadDeleteBehavior do
  use Buffer.Read, behavior: :delete
  def read, do: BufferKeyListResult.dump_table
end

defmodule BufferSync do
  use Buffer.Sync
  def read(numbers) do
    for number <- numbers, do: {number, number*2}
  end

  def write(elements) do
    for {key, value} <- elements, do: BufferKeyListResult.add(key, value)
  end
end

defmodule BufferReadNil do
  use Buffer.Read, synchronize: true
  def read do
    results = :ets.lookup(:read_nil, "read_nil")
    case results do
      [{"read_nil", value}] ->
        value
      _ -> []
    end
  end
end
