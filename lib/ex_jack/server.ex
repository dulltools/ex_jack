defmodule ExJack.Server do
  use GenServer

  defstruct handler: nil,
            shutdown_handler: nil,
            current_frame: 0,
            output_func: &ExJack.Server.noop/1,
            input_func: &ExJack.Server.noop/1

  @type t :: %__MODULE__{
          handler: any(),
          shutdown_handler: any(),
          current_frame: pos_integer(),
          output_func: output_func_t,
          input_func: input_func_t
        }

  @type frames_t :: list(float())
  @type output_func_t :: (Range.t() -> frames_t)
  @type input_func_t :: (frames_t -> any())
  @type options_t :: %{name: String.t()}

  def noop(_) do
    []
  end

  @spec start_link(options_t) :: GenServer.server()
  def start_link(%{name: _} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec set_output_func(output_func_t) :: GenServer.server()
  def set_output_func(output_func) do
    GenServer.cast(__MODULE__, {:set_output_func, output_func})
  end

  @spec set_input_func(input_func_t) :: GenServer.server()
  def set_input_func(input_func) do
    GenServer.cast(__MODULE__, {:set_input_func, input_func})
  end

  @spec send_frames(output_func_t) :: GenServer.server()
  def send_frames(frames) do
    unless Enum.empty?(frames) do
      GenServer.cast(__MODULE__, {:send_frames, frames})
    end
  end

  @impl true
  @spec init(options_t) :: {:ok, map()}
  def init(opts) do
    {:ok, handler, shutdown_handler, _opts} = ExJack.Native.start(opts)

    {:ok, %__MODULE__{handler: handler, shutdown_handler: shutdown_handler, current_frame: 0}}
  end

  @impl true
  @spec handle_cast({:set_output_func, output_func_t}, t()) :: {:noreply, t()}
  def handle_cast({:set_output_func, output_func}, state) do
    {:noreply, %{state | output_func: output_func}}
  end

  @impl true
  @spec handle_cast({:set_input_func, output_func_t}, t()) :: {:noreply, t()}
  def handle_cast({:set_input_func, output_func}, state) do
    {:noreply, %{state | input_func: output_func}}
  end


  @impl true
  @spec handle_cast({:send_frames, frames_t}, t()) :: {:noreply, t()}
  def handle_cast({:send_frames, frames}, %{handler: handler} = state) do
    ExJack.Native.send_frames(handler, frames)

    {:noreply, state}
  end

  @impl true
  @spec handle_info({:in_frames, frames_t}, t()) :: {:noreply, t()}
  def handle_info({:in_frames, frames}, %{input_func: input_func} = state) do
    input_func.(frames)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:request, pos_integer()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:request, requested_frames},
        %{current_frame: current_frame, output_func: output_func} = state
      ) do
    end_frames = current_frame + requested_frames - 1
    send_frames(output_func.(current_frame..end_frames))

    {:noreply, %{state | current_frame: end_frames + 1}}
  end

  @impl true
  def terminate(_reason, %{shutdown_handler: shutdown_handler}) do
    ExJack.Native.stop(shutdown_handler)
    :ok
  end
end
