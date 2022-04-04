defmodule ExJack.Server do
  @moduledoc """
  A GenServer module that interfaces with JACK audio API I/O.

  There are two methods for outputting sound to JACK:
  1. Calling `send_frames/1`
  2. Setting an output function using `set_output_func/1`, which JACK
     calls every time it wants frames.

  At the moment, there is only one method of retrieving input data, which is to set
  an input callback using `set_input_func/1`.

  Latency will obviously vary and if you have a busy machine, expect xruns. xruns,
  which is shorthand for overruns and underruns, occur when you either send too
  many frames or not enough frames. If the CPU is busy doing some other work
  and neglects to send frames to the soundcard, the soundcard buffer runs out of frames 
  to play. An underrun will then occur. You could send too many frames to the 
  soundcard. If you send more than its buffers can hold, the data will be lost. This
  is an overrun.
  """

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
  @type options_t :: %{
    name: String.t(),
    use_callback: boolean(),
    auto_connect: boolean(),
  }

  @doc """
  Start the server.

  JACK NIF will start a thread that runs the JACK client.

  It will auto-connect to two standard channels which you can modify
  through JACK.

  ## Parameters
   - name: Used to name the JACK node (suffixed with `:in` and `:out`)

   e.g. If you pass `%{name: "HelloWorld"}`, you can interface with this
   connection within JACK through `HelloWorld:in` and `HelloWorld:out`.
  """
  @spec start_link(options_t) :: GenServer.server()
  def start_link(%{name: _name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Set the callback function that JACK will call when it requests more frames.
  """
  @spec set_output_func(output_func_t) :: :ok
  def set_output_func(output_func) do
    GenServer.cast(__MODULE__, {:set_output_func, output_func})
  end

  @doc """
  Set the callback function that will receive input data from JACK each cycle.

  The output of the function is currently not used for anything.
  """
  @spec set_input_func(input_func_t) :: :ok
  def set_input_func(input_func) do
    GenServer.cast(__MODULE__, {:set_input_func, input_func})
  end

  @doc """
  Sends a list of frames for JACK to play during its next cycle.
  """
  @spec send_frames(frames_t) :: :ok
  def send_frames(frames) do
    unless Enum.empty?(frames) do
      GenServer.cast(__MODULE__, {:send_frames, frames})
    end
  end

  @impl true
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

  @doc false
  def noop(_) do
    []
  end
end
