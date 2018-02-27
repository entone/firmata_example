defmodule FirmataExample.NeoPixel do
  use GenServer
  require Logger

  @pause 1

  defmodule Colors do
    defstruct [
      red: {255, 0, 0},
      orange: {150, 127, 0},
      yellow: {255, 255, 0},
      green: {0, 255, 0},
      blue: {0, 0, 255},
      indigo: {75, 0, 130},
      white: {255, 255, 255}
    ]
  end

  defmodule Streams do
    defstruct [
      blues: [{255, 255, 255},{229, 239, 249},{211, 228, 243},{190, 216, 236},{162, 203, 227},{128, 185, 218},{94, 165, 209},{66, 144, 197},{42, 121, 184},{22, 98, 168},{10, 74, 144},{0, 0, 255}],
      greens: [{255, 255, 255},{233, 247, 229},{215, 240, 210},{192, 230, 186},{165, 218, 159},{134, 204, 133},{99, 188, 111},{67, 169, 92},{42, 147, 75},{19, 124, 57},{3, 100, 41},{0, 255, 0}],
      oranges: [{255, 255, 255},{254, 234, 213},{254, 220, 186},{253, 201, 152},{253, 178, 115},{253, 154, 79},{248, 129, 47},{238, 104, 22},{221, 81, 7},{192, 64, 2},{159, 51, 3},{130, 40, 4}],
      purples: [{255, 251, 255},{242, 241, 247},{229, 228, 240},{212, 212, 232},{192, 192, 221},{170, 168, 208},{148, 145, 196},{128, 121, 184},{111, 92, 169},{95, 61, 154},{80, 31, 140},{65, 3, 126}],
      reds: [{255, 255, 255},{254, 229, 217},{253, 207, 188},{252, 180, 154},{252, 151, 120},{251, 122, 90},{246, 91, 65},{234, 59, 46},{211, 34, 33},{184, 20, 25},{151, 11, 19},{255, 0, 0}]
    ]
  end

  def start_link(board, pin, num_pixels) do
    GenServer.start_link(__MODULE__, {board, pin, num_pixels}, name: __MODULE__)
  end

  def init({board, pin, num_pixels}) do
    Logger.info "Starting NeoPixel"
    board |> Firmata.Board.neopixel_register(pin, num_pixels)
    board |> Firmata.Board.neopixel_brightness(0)
    Logger.info "NeoPixel Registered"
    colors = %Colors{}
    streams = %Streams{}
    Process.send_after(self(), {:pulse, colors.red, 4}, @pause)
    Process.send_after(self(), {:follow, streams.oranges, 7}, 3000)
    Process.send_after(self(), {:follow, streams.blues, 7}, 9000)
    Process.send_after(self(), {:watch_distance, colors.blue}, 13000)
    Process.send_after(self(), {:tac, colors.green}, 25000)
    Logger.info "NeoPixel Started"
    {:ok, %{board: board, pin: pin, num_pixels: num_pixels, running: nil}}
  end

  def set_color(board, color, num_pixels, brightness \\ 1) do
    :timer.sleep(@pause)
    board |> Firmata.Board.neopixel_brightness(brightness)
    :timer.sleep(@pause)
    0..num_pixels |> Enum.each(fn i ->
      board |> Firmata.Board.neopixel(i, color)
      :timer.sleep(@pause)
    end)
    :timer.sleep(@pause)
  end

  def handle_info({:tac, color}, state) do
    val = FirmataExample.Distance.value()
    diff = 196
    multi = 11 / diff
    tac = (val * multi) |> Float.floor |> round()
    tac..12 |> Enum.each(fn i ->
      state.board |> Firmata.Board.neopixel(i, {0,0,0})
      :timer.sleep(@pause)
    end)
    set_color(state.board, color, (tac - 1), 45)
    Process.send_after(self(), {:tac, color}, 100)
    {:noreply, %{state | running: :tac}}
  end

  def handle_info({:watch_distance, color}, state) do
    set_color(state.board, color, state.num_pixels, 1)
    Process.send_after(self(), :watch, 100)
    {:noreply, %{state | running: :watch}}
  end

  def handle_info(:watch, state) do
    val = FirmataExample.Distance.value()
    diff = 196 #total distance of 200cm and a minimum of 4cm
    multi = 100 / diff #max 100 brightness, 255 is crazy bright
    brightness = (val * multi) |> Float.floor |> round()
    brightness = [100, brightness] |> Enum.min()
    brightness = [1, brightness] |> Enum.max()
    state.board |> Firmata.Board.neopixel_brightness(brightness)
    case state.running do
      :watch -> Process.send_after(self(), :watch, 100)
      _ -> :noop
    end
    {:noreply, state}
  end

  def handle_info({:follow, color, times}, state) do
    state.board |> Firmata.Board.neopixel_brightness(20)
    :timer.sleep(@pause)
    0..(state.num_pixels - 1) |> Enum.each(fn i ->
      c = color |> Enum.at(i)
      state.board |> Firmata.Board.neopixel(i, c)
      :timer.sleep(@pause)
    end)
    do_follow(state.board, state.num_pixels, color, times)
    {:noreply, state}
  end

  def do_follow(board, num_pixels, color, times, front \\ 0, count \\ 0) do
    h = front..(num_pixels - 1) |> Enum.map(fn i -> i end)
    t =
      case front > 0 do
        true -> 0..(front - 1) |> Enum.map(fn i -> i end)
        false -> []
      end
    ar = h ++ t
    ar |> Enum.with_index() |> Enum.each(fn {pixel, i}  ->
      c = color |> Enum.at(i)
      board |> Firmata.Board.neopixel(pixel, c)
      :timer.sleep(@pause)
    end)
    {n_front, total} =
      case front == (num_pixels - 1) do
        true -> {0, count + 1}
        false -> {front + 1, count}
      end
      case total == times do
        true ->
          board |> Firmata.Board.neopixel_brightness(0)
          :noop
        false ->
          :timer.sleep(5)
          do_follow(board, num_pixels, color, times, n_front, total)
      end
  end

  def handle_info({:pulse, color, times}, state) do
    set_color(state.board, color, state.num_pixels, 1)
    do_pulse(state.board, times)
    {:noreply, state}
  end

  def do_pulse(board, times, count \\ 0, step \\ 1, dir \\ :plus) do
    board |> Firmata.Board.neopixel_brightness(step)
    {n_step, n_dir, total} =
      case dir do
        :plus ->
          next = step + 10
          case next >= 100 do
            true -> {100, :minus, count}
            false -> {next, :plus, count}
          end
        :minus ->
          next = step - 10
          case next <= 0 do
            true -> {1, :plus, count + 1}
            false -> {next, :minus, count}
          end
      end
    case total == times do
      true ->
        board |> Firmata.Board.neopixel_brightness(0)
        :noop
      false ->
        :timer.sleep(50)
        do_pulse(board, times, total, n_step, n_dir)
    end
  end
end
