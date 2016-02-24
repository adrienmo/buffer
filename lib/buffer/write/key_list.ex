defmodule Buffer.Write.KeyList do
  use GenServer
  use Behaviour

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
      @on_load :on_load

      def on_load do
        Buffer.Supervisor.add_child(__MODULE__)
        :ok
      end

      def worker do
        import Supervisor.Spec
        state = %{
          name: __MODULE__,
          interval: unquote(opts[:interval]),
          write: &write/1,
          limit: unquote(opts[:limit])
        }
        worker(unquote(__MODULE__), [state], id: __MODULE__)
      end

      def add(key, element), do: unquote(__MODULE__).add(__MODULE__, key, element, unquote(opts[:limit]))

      def dump_table(), do: unquote(__MODULE__).dump_table(__MODULE__)
      def reset(), do: unquote(__MODULE__).reset(__MODULE__)

      def sync(), do: unquote(__MODULE__).sync(__MODULE__)
    end
  end

  @doc "Write function"
  defcallback write([{key :: any(), element :: any()}]) :: any()

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, [name: state.name])
  end

  def sync(name), do: GenServer.call(name, :sync)
  def sync(name, key), do: GenServer.call(name, {:sync, key})

  def init(state) do
    :ets.new(state.name, [:public, :duplicate_bag, :named_table, {:write_concurrency, true}])
    unless is_nil(state.interval) do
      Process.send_after(self(), :sync, state.interval)
    end
    {:ok, state}
  end

  def add(name, key, element, nil) do
    :ets.insert(name, {key, element})
  end
  def add(name, key, element, limit) do
    add(name, key, element, nil)
    count = :ets.select_count(name, [{{key, :_}, [], [true]}])
    if count >= limit, do: sync(name, key)
  end

  def handle_call(:sync, _, state) do
    write(state)
    {:reply, :ok, state}
  end
  def handle_call({:sync, key}, _, state) do
    write(state, key)
    {:reply, :ok, state}
  end

  def handle_info(:sync, state) do
    Process.send_after(self(), :sync, state.interval)
    write(state)
    {:noreply, state}
  end

  def dump_table(name), do: :ets.tab2list(name)
  def reset(name), do: :ets.delete_all_objects(name)

  defp write(state), do: state.name |> get_elements() |> state.write.()
  defp write(state, key) do
    key_list = get_key_list(state.name, key)
    state.write.([key_list])
  end

  defp get_elements(name), do: get_elements(name, :ets.first(name), [])
  defp get_elements(_, :"$end_of_table", acc), do: acc
  defp get_elements(name, key, acc) do
    next_key = :ets.next(name, key)
    key_list = get_key_list(name, key)
    get_elements(name, next_key, [key_list| acc])
  end

  defp get_key_list(name, key) do
    element = :ets.take(name, key)
    {key, Enum.map(element, &(elem(&1, 1)))}
  end
end
