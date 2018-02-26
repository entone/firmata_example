defmodule FirmataExample.Application do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    #{firmata_tty, _board} = firmata_tty()
    children = [
      worker(FirmataExample.UARTProbe, []),
      worker(FirmataExample.WaitForDevices, []),
      worker(FirmataExample.Board, []),
    ]
    opts = [strategy: :one_for_one, name: FirmataExample.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
