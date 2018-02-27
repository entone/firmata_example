defmodule FirmataExample.Board do
  use GenServer
  use Firmata.Protocol.Mixin
  require Logger

  @neopixel_pin 8
  @num_pixels 12

  @distance_pin 11

  defmodule State do
    defstruct firmata: nil, started: false
  end

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    tty = FirmataExample.UARTProbe.devices() |> Map.get(:firmata)
    Logger.debug "#{inspect tty}"
    {:ok, firmata} = Firmata.Board.start_link(tty, [speed: 115200], FirmataExample.Firmata.Board)
    Logger.info "Firmata Started: #{inspect firmata}"
    Firmata.Board.sysex_write(firmata, @firmware_query, <<>>)
    {:ok, %State{firmata: firmata}}
  end

  def init_board(state) do
    FirmataExample.Distance.start_link(state.firmata, @distance_pin)
    FirmataExample.NeoPixel.start_link(state.firmata, @neopixel_pin, @num_pixels)
    %State{state | started: true}
  end

  def handle_info({:firmata, {:pin_map, pin_map}}, state) do
    Logger.info "Ready: Pin Map #{inspect pin_map}"
    state =
      case state.started do
        false -> state |> init_board()
        true -> state
      end
    {:noreply, state}
  end

  def handle_info({:firmata, {:version, major, minor}}, state) do
    Logger.info "Firmware Version: v#{major}.#{minor}"
    {:noreply, state}
  end

  def handle_info({:firmata, {:firmware_name, name}}, state) do
    Logger.info "Firmware Name: #{name}"
    {:noreply, state}
  end

  def handle_info({:firmata, {:string_data, value}}, state) do
    Logger.debug value
    {:noreply, state}
  end

  def handle_info({:firmata, {:sonar_data, channel, value}}, state) do
    FirmataExample.Distance.parse({:sonar_data, channel, value})
    {:noreply, state}
  end

  def handle_info({:firmata, info}, state) do
    Logger.error "Unknown Firmata Data: #{inspect info}"
    {:noreply, state}
  end

end
