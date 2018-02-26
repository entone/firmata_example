defmodule FirmataExample.UARTProbe do
  use GenServer
  require Logger

  @firmata "firmata"

  defmodule State do
    defstruct [:firmata, pids: %{}]
  end

  def devices(), do: GenServer.call(__MODULE__, :devices)

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    uart_opts = [speed: 115200, active: true, framing: {Nerves.UART.Framing.Line, separator: "\n"}]
    pids =
      Nerves.UART.enumerate() |> Enum.reduce(%{}, fn {k, v}, acc ->
        Logger.info "Open #{k}"
        {:ok, uart} = Nerves.UART.start_link()
        Logger.info "#{inspect uart}"
        open = Nerves.UART.open(uart, k, uart_opts)
        Nerves.UART.write(uart, <<0xFF>>)
        Map.put(acc, k, uart)
      end)
    Logger.info "#{__MODULE__} started"
    {:ok, %State{pids: pids}}
  end

  def handle_info({:nerves_uart, tty, @firmata}, state) do
    Logger.info "Got Firmata: #{tty}"
    pid = Map.get(state.pids, tty)
    case Process.alive?(pid) do
      true ->
        Nerves.UART.close(pid)
        Nerves.UART.stop(pid)
      _ -> :noop
    end
    {:noreply, %State{state | firmata: tty}}
  end

  def handle_info({:nerves_uart, tty, data}, state) do
    Logger.info "#{inspect tty}"
    Logger.info "#{inspect data}"
    {:noreply, state}
  end

  def handle_call(:devices, _from, state) do
    {:reply, state, state}
  end
end
