defmodule Buffer.Write.Count do
  use GenServer

  @default_interval 1000

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: :macros
    end
  end

  defmacro buffer(opts) do
    interval = :proplists.get_value(:interval, opts, @default_interval)
    write = :proplists.get_value(:write, opts)
    quote do
      def worker do
        import Supervisor.Spec
        buffer = %{
          name: __MODULE__,
          interval: unquote(interval),
          write: unquote(write)
        }
        worker(unquote(__MODULE__), [buffer], id: __MODULE__)
      end

      def incr(key), do: unquote(__MODULE__).incr(__MODULE__, key, 1)
      def incr(key, value), do: unquote(__MODULE__).incr(__MODULE__, key, value)

      def sync(), do: unquote(__MODULE__).sync(__MODULE__)
    end
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, [name: state.name])
  end

  def sync(name) do
    GenServer.call(name, :sync)
  end

  def init(state) do
    :ets.new(state.name, [:public, :set, :named_table, {:write_concurrency, true}])
    unless is_nil(state.interval) do
      Process.send_after(self(), :sync, state.interval)
    end
    {:ok, state}
  end

  def incr(name, key, value) do
    :ets.update_counter(name, key, value, {key, 0})
  end

  def handle_call(:sync, _, state) do
    write(state)
    {:reply, :ok, state}
  end

  def handle_info(:sync, state) do
    Process.send_after(self(), :sync, state.interval)
    write(state)
    {:noreply, state}
  end

  defp write(state), do: state.name |> get_counters() |> state.write.()

  defp get_counters(name), do: get_counters(name, :ets.first(name), [])
  defp get_counters(_, :"$end_of_table", acc), do: acc
  defp get_counters(name, key, acc) do
    next_key = :ets.next(name, key)
    element = :ets.take(name, key) |> hd()
    get_counters(name, next_key, [element| acc])
  end
end
