defmodule BufferTest do
  use ExUnit.Case

  setup_all do
    TestSupervisor.start_link()
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

    BufferCount.sync()

    result = BufferKeyListResult.dump_table()
    assert([{_, [key2: 5050, key1: 100]}] = result)
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

    assert(field1_5[:key3] != nil)
    assert(field2_4[:key3] != nil)
    assert(field2_4[:key4] != nil)
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

  defp get_match_spec(fun_string) do
    fun_string
    |> Code.eval_string()
    |> elem(0)
    |> :ets.fun2ms()
  end
end

defmodule TestSupervisor do
  use Supervisor
  def start_link do
    Supervisor.start_link(TestSupervisor, [])
  end

  def init([]) do
    children = [
      BufferKeyListResult.worker,
      BufferKeyListLimit.worker,
      BufferKeyListInterval.worker,
      BufferCount.worker,
      BufferRead.worker,
      BufferReadUpdate.worker,
      BufferReadDefaultBehavior.worker,
      BufferReadDeleteBehavior.worker
    ]
    supervise(children, strategy: :one_for_one, max_restarts: 1, max_seconds: 1)
  end
end

defmodule BufferKeyListResult do
  use Buffer.Write.KeyList
  def write(_), do: nil
end

defmodule BufferKeyListLimit do
  use Buffer.Write.KeyList, limit: 10
  def write(keylists) do
    BufferKeyListResult.add(__MODULE__, keylists)
  end
end

defmodule BufferKeyListInterval do
  use Buffer.Write.KeyList, interval: 1000, limit: nil
  def write(keylists) do
    BufferKeyListResult.add(__MODULE__, keylists)
  end
end

defmodule BufferCount do
  use Buffer.Write.Count
  def write(counters) do
    BufferKeyListResult.add(__MODULE__, counters)
  end
end

defmodule BufferRead do
  use Buffer.Read
  def read() do
    [
      {:key1, "value1"},
      {:key2, "value2"},
      {:key3, %{field1: 5, field2: 4}},
      {:key4, %{field1: 4, field2: 4}}
    ]
  end
end

defmodule BufferReadUpdate do
  use Buffer.Read, on_element_updated: &update/1
  def read() do
    BufferKeyListResult.dump_table()
  end

  def update(x) do
    BufferKeyListResult.add(__MODULE__, x)
  end
end

defmodule BufferReadDefaultBehavior do
  use Buffer.Read
  def read() do
    BufferKeyListResult.dump_table()
  end
end

defmodule BufferReadDeleteBehavior do
  use Buffer.Read, behavior: :delete
  def read() do
    BufferKeyListResult.dump_table()
  end
end
