defmodule Buffer.Read do
  use GenServer

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: :macros
    end
  end

  defmacro buffer(opts) do
    quote do
      def worker do
        import Supervisor.Spec
        state = %{
          name: __MODULE__,
          interval: unquote(opts[:interval]),
          read: unquote(opts[:read]),
          on_element_updated: unquote(opts[:on_element_updated]),
          behavior: unquote(opts[:behavior])
        }
        worker(unquote(__MODULE__), [state], id: __MODULE__)
      end

      def get(key), do: unquote(__MODULE__).get(__MODULE__, key)
      def select(match_spec), do: unquote(__MODULE__).select(__MODULE__, match_spec)
      def sync(), do: unquote(__MODULE__).sync(__MODULE__)
      def dump_table(), do: unquote(__MODULE__).dump_table(__MODULE__)
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

  def get(name, key) do
    case :ets.lookup(name, key) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  def dump_table(name), do: :ets.tab2list(name)

  def select(name, match_spec) do
    :ets.select(name, match_spec)
  end

  def delete(name, key) do
    :ets.delete(name, key)
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

  defp read(state) do
    elements = state.read.()

    if state.behavior == :delete do
      match_spec = [{{:"$1", :_}, [], [:"$1"]}]
      old_ids = select(state.name, match_spec)
      new_ids = Enum.map(elements, fn({id, _}) -> id end)
      for id <- (old_ids -- new_ids), do: delete(state.name, id)
    end

    if state.on_element_updated != nil do
      updated_ids = Enum.reduce(elements, [], fn({id, element}, acc) ->
        if element != get(state.name, id) do
          [id | acc]
        else
          acc
        end
      end)

      unless updated_ids == [], do: state.on_element_updated.(updated_ids)
    end

    :ets.insert(state.name, elements)
  end
end
