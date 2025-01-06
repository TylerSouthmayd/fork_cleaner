defmodule ForkCleaner.Application do
  use Application

  def start(_type, _args) do
    ForkCleaner.clean_forks()
    System.halt(0)
  end
end
