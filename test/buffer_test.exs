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

  test "0000# KeyList, Limit + Sync" do
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

  test "0001# KeyList, Interval" do
    1..4 |> Enum.map(&(BufferKeyListInterval.add(1, &1)))

    result = BufferKeyListResult.dump_table()
    assert([] == result)

    :timer.sleep(1000)

    result = BufferKeyListResult.dump_table()
    assert([{_, [{1, [1, 2, 3, 4]}]}] = result)
  end

  test "0010# Count, Sync" do
    for x <- 1..100, do: BufferCount.incr(:key1)
    for x <- 1..100, do: BufferCount.incr(:key2, x)

    BufferCount.sync()

    result = BufferKeyListResult.dump_table()
    assert([{_, [key2: 5050, key1: 100]}] = result)
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
      BufferCount.worker
    ]
    supervise(children, strategy: :one_for_one, max_restarts: 1, max_seconds: 1)
  end
end

defmodule BufferKeyListResult do
  use Buffer.Write.KeyList
  buffer interval: nil, limit: nil, write: &write/1
  def write(_), do: nil
end

defmodule BufferKeyListLimit do
  use Buffer.Write.KeyList
  buffer interval: nil, limit: 10, write: &write/1
  def write(keylists) do
    BufferKeyListResult.add(__MODULE__, keylists)
  end
end

defmodule BufferKeyListInterval do
  use Buffer.Write.KeyList
  buffer interval: 1000, limit: nil, write: &write/1
  def write(keylists) do
    BufferKeyListResult.add(__MODULE__, keylists)
  end
end

defmodule BufferCount do
  use Buffer.Write.Count
  buffer interval: nil, write: &write/1
  def write(counters) do
    BufferKeyListResult.add(__MODULE__, counters)
  end
end
