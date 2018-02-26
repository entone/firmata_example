defmodule FirmataExample.WaitForDevices do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Logger.info "Waiting for device(s)"
    devices = wait_for_devices()
    {:ok, %{}}
  end

  def wait_for_devices() do
    devices = FirmataExample.UARTProbe.devices()
    case devices |> Map.to_list |> Enum.any?(fn {k, v} -> v == nil end) do
      false -> devices
      true ->
        :timer.sleep(100)
        wait_for_devices()
    end
  end
end
