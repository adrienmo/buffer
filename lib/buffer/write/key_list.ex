defmodule Buffer.Write.KeyList do
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

      def add(key, element), do: unquote(__MODULE__).add(__MODULE__, key, element)

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
    :ets.new(state.name, [:public, :duplicate_bag, :named_table, {:write_concurrency, true}])
    Process.send_after(self(), :sync, state.interval)
    {:ok, state}
  end

  def add(name, key, element) do
    :ets.insert(name, {key, element})
  end

  def handle_call(:sync, _, state) do
    write(state)
    {:reply, :ok, state}
  end

  def handle_info(:sync, state) do
    unless is_nil(state.interval) do
      Process.send_after(self(), :sync, state.interval)
      write(state)
    end
    {:noreply, state}
  end

  defp write(state), do: state.name |> get_element() |> state.write.()

  defp get_element(name), do: get_element(name, :ets.first(name), [])
  defp get_element(_, :"$end_of_table", acc), do: acc
  defp get_element(name, key, acc) do
    next_key = :ets.next(name, key)
    element = :ets.take(name, key)
    key_list = {key, Enum.map(&(elem(&1, 1)))}
    get_element(name, next_key, [key_list| acc])
  end
end
