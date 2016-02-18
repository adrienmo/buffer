defmodule Buffer.Read do
  use GenServer

  @default_interval 1000

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: :macros
    end
  end

  defmacro buffer(opts) do
    interval = :proplists.get_value(:read_interval, opts, @default_interval)
    read_fun = :proplists.get_value(:read_function, opts)
    quote do
      def worker do
        import Supervisor.Spec
        buffer = %{
          name: __MODULE__,
          interval: unquote(interval),
          read_fun: unquote(read_fun)
        }
        worker(unquote(__MODULE__), [buffer], id: __MODULE__)
      end

      def read(key), do: unquote(__MODULE__).read(__MODULE__, key)

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
    :ets.new(state.name, [:public, :set, :named_table, {:read_concurrency, true}])
    Process.send_after(self(), :sync, 0)
    {:ok, state}
  end

  def read(name, key) do
    case :ets.lookup(name, key) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  def handle_call(:sync, _, state) do
    read(state)
    {:reply, :ok, state}
  end

  def handle_info(:sync, state) do
    unless is_nil(state.interval) do
      Process.send_after(self(), :sync, state.interval)
    end
    read(state)
    {:noreply, state}
  end

  defp read(state), do: :ets.insert(state.name, state.read_fun.())
end
