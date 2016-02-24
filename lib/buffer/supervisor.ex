defmodule Buffer.Supervisor do
  use Supervisor

  # Wait for the module to be available. (Maybe found a better way to do this)
  @refresh_delay 10

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    supervise([], strategy: :one_for_one, max_restarts: 1, max_seconds: 1)
  end

  def add_child(name) do
    spawn(__MODULE__, :start_child, [name])
  end

  def start_child(name) do
    if function_exported?(name, :worker, 0) do
      child_spec = apply(name, :worker, [])
      Supervisor.start_child(__MODULE__, child_spec)
    else
      :timer.sleep(@refresh_delay)
      start_child(name)
    end
  end
end
