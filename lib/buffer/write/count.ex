defmodule Buffer.Write.Count do
  use GenServer
  use Behaviour

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)

      def worker do
        import Supervisor.Spec
        state = %{
          name: __MODULE__,
          interval: unquote(opts[:interval]),
          write: &write/1
        }
        worker(unquote(__MODULE__), [state], id: __MODULE__)
      end

      def incr(key), do: unquote(__MODULE__).incr(__MODULE__, key, 1)
      def incr(key, value), do: unquote(__MODULE__).incr(__MODULE__, key, value)
      def sync(), do: unquote(__MODULE__).sync(__MODULE__)
      def dump_table(), do: unquote(__MODULE__).dump_table(__MODULE__)
      def reset(), do: unquote(__MODULE__).reset(__MODULE__)
    end
  end

  @doc "Write function"
  defcallback write([{key :: any(), element :: any()}]) :: any()

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

  def dump_table(name), do: :ets.tab2list(name)
  def reset(name), do: :ets.delete_all_objects(name)

  defp write(state), do: state.name |> get_counters() |> state.write.()

  defp get_counters(name), do: get_counters(name, :ets.first(name), [])
  defp get_counters(_, :"$end_of_table", acc), do: acc
  defp get_counters(name, key, acc) do
    next_key = :ets.next(name, key)
    element = :ets.take(name, key) |> hd()
    get_counters(name, next_key, [element| acc])
  end
end
