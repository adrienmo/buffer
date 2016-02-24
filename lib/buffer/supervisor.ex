defmodule Buffer.Supervisor do
  use Supervisor

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
    child_spec = apply(name, :worker, [])
    Supervisor.start_child(__MODULE__, child_spec)
  end
end
