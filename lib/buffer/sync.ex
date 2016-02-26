defmodule Buffer.Sync do
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
          read: &read/1,
          write: &write/1,
          elements_to_sync: []
        }
        worker(unquote(__MODULE__), [state], id: __MODULE__)
      end

      def delete(element), do: unquote(__MODULE__).delete(__MODULE__, element)
      def add(element), do: unquote(__MODULE__).add(__MODULE__, element)
      def sync(), do: unquote(__MODULE__).sync(__MODULE__)
      def reset(), do: unquote(__MODULE__).reset(__MODULE__)
    end
  end

  @doc "Read function"
  defcallback read([any()]) :: [any()]

  @doc "Write function"
  defcallback write([any()]) :: any()

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, [name: state.name])
  end

  def add(name, element), do: GenServer.call(name, {:add, element})
  def delete(name, element), do: GenServer.call(name, {:delete, element})
  def sync(name), do: GenServer.call(name, :sync)
  def reset(name), do: GenServer.call(name, :reset)

  def init(state) do
    Process.send_after(self(), :sync, 0)
    {:ok, state}
  end

  def handle_call(:sync, _, state), do: {:reply, :ok, _sync(state)}
  def handle_call(:reset, _, state), do: {:reply, :ok, _reset(state)}
  def handle_call({:add, element}, _, state), do: {:reply, :ok, _add(state, element)}
  def handle_call({:delete, element}, _, state), do: {:reply, :ok, _delete(state, element)}

  def handle_info(:sync, state) do
    unless is_nil(state.interval) do
      Process.send_after(self(), :sync, state.interval)
    end
    _sync(state)
    {:noreply, state}
  end

  defp _sync(state) do
    state.elements_to_sync |> state.read.() |> state.write.()
    state
  end

  defp _reset(state) do
    %{state | elements_to_sync: []}
  end

  defp _add(state, element) do
    %{state | elements_to_sync: [element | state.elements_to_sync]}
  end

  defp _delete(state, element) do
    %{state | elements_to_sync: state.elements_to_sync -- [element]}
  end
end
