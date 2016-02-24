defmodule Buffer do
  use Application

  def start(_type, _args) do
    Buffer.Supervisor.start_link()
  end
end
