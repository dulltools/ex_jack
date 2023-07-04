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
  require Logger

  defstruct handler: nil,
            shutdown_handler: nil,
            port_handler: nil,
            current_frame: 0,
            buffer_size: 0,
            sample_rate: 44100,
            output_func: &ExJack.Server.noop/1,
            input_func: &ExJack.Server.noop/1,
            ports: MapSet.new(),
            clients: MapSet.new()

  @type t :: %__MODULE__{
          handler: any(),
          shutdown_handler: any(),
          port_handler: any(),
          current_frame: pos_integer(),
          buffer_size: buffer_size_t,
          sample_rate: sample_rate_t,
          output_func: output_func_t,
          input_func: input_func_t,
          ports: ports_t,
          clients: MapSet.t(client_name_t)
        }

  # `client_name_t:port_short_name_t`
  @type port_name_t :: String.t()
  @type port_short_name_t :: String.t()
  @type client_name_t :: String.t()
  @type port_t :: %{
          name: port_short_name_t,
          client: client_name_t,
          connections: MapSet.t(port_name_t)
        }

  @type ports_t :: %{
          port_name_t: port_t
        }

  @type sample_rate_t :: pos_integer()
  @type buffer_size_t :: pos_integer()
  @type frames_t :: list(float())
  @type output_func_t :: (Range.t() -> frames_t)
  @type input_func_t :: (frames_t -> any())
  @type options_t :: %{
          name: String.t(),
          use_callback: boolean(),
          auto_connect: boolean()
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
  Returns the size of JACK's buffer
  """
  @spec get_buffer_size() :: buffer_size_t()
  def get_buffer_size() do
    GenServer.call(__MODULE__, :buffer_size)
  end

  @doc """
  Returns the sample rate in Hz that JACK is operating with
  """
  @spec get_sample_rate() :: sample_rate_t()
  def get_sample_rate() do
    GenServer.call(__MODULE__, :sample_rate)
  end

  @doc """
  Returns list of ports with their connections
  """
  @spec get_ports() :: ports_t
  def get_ports() do
    GenServer.call(__MODULE__, :ports)
  end

  @doc """
  Connect an output port to an input port
  """
  @spec connect_ports(port_t, port_t) :: any()
  def connect_ports(port_from_name, port_to_name) do
    GenServer.call(__MODULE__, {:connect_ports, port_from_name, port_to_name})
  end

  @doc """
  Disconnect an output port to an input port
  """
  @spec disconnect_ports(port_t, port_t) :: any()
  def disconnect_ports(port_from_name, port_to_name) do
    GenServer.call(__MODULE__, {:disconnect_ports, port_from_name, port_to_name})
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
    {:ok, handler, shutdown_handler, port_handler, ports,
     %{buffer_size: buffer_size, sample_rate: sample_rate}} = ExJack.Native.start(opts)

    {:ok,
     %__MODULE__{
       handler: handler,
       shutdown_handler: shutdown_handler,
       port_handler: port_handler,
       current_frame: 0,
       buffer_size: buffer_size,
       sample_rate: sample_rate,
       ports:
         Enum.map(ports, fn name ->
           {name, String.split(name, ":")}
         end)
         |> Map.new(fn {name, [client, short_name]} ->
           {name,
            %{
              client: client,
              name: short_name,
              connections: MapSet.new()
            }}
         end)
     }}
  end

  @impl true
  @spec handle_call(:buffer_size, any(), t()) :: {:reply, buffer_size_t(), t()}
  def handle_call(:buffer_size, _from, %{buffer_size: buffer_size} = state) do
    {:reply, buffer_size, state}
  end

  @impl true
  @spec handle_call(:sample_rate, any(), t()) :: {:reply, sample_rate_t(), t()}
  def handle_call(:sample_rate, _from, %{sample_rate: sample_rate} = state) do
    {:reply, sample_rate, state}
  end

  @impl true
  @spec handle_call(:ports, any(), t()) :: {:reply, ports_t(), t()}
  def handle_call(:ports, _from, %{ports: ports} = state) do
    {:reply, ports, state}
  end

  @impl true
  @spec handle_call({:connect_ports, port_t, port_t}, GenServer.from(), t()) ::
          {:reply, ports_t(), t()}
  def handle_call(
        {:connect_ports, port_from_name, port_to_name},
        _from,
        %{ports: ports, port_handler: port_handler} = state
      ) do
    if Map.has_key?(ports, port_from_name) and Map.has_key?(ports, port_to_name) do
      ret = ExJack.Native.connect_ports(port_handler, port_from_name, port_to_name)
      {:reply, ret, state}
    else
      {:reply, {:error, :ports_not_found}, state}
    end
  end

  @impl true
  @spec handle_call({:disconnect_ports, port_t, port_t}, GenServer.from(), t()) ::
          {:reply, ports_t(), t()}
  def handle_call(
        {:disconnect_ports, port_from_name, port_to_name},
        _from,
        %{ports: ports, port_handler: port_handler} = state
      ) do
    if Map.has_key?(ports, port_from_name) and Map.has_key?(ports, port_to_name) do
      ret = ExJack.Native.disconnect_ports(port_handler, port_from_name, port_to_name)
      {:reply, ret, state}
    else
      {:reply, {:error, :ports_not_found}, state}
    end
  end

  @impl true
  @spec handle_cast({:set_output_func, output_func_t}, t()) :: {:noreply, t()}
  def handle_cast({:set_output_func, output_func}, state) do
    {:noreply, %{state | output_func: output_func}}
  end

  @impl true
  @spec handle_cast({:set_input_func, input_func_t}, t()) :: {:noreply, t()}
  def handle_cast({:set_input_func, input_func}, state) do
    {:noreply, %{state | input_func: input_func}}
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
  @spec handle_info({:request, pos_integer()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:request, requested_frames},
        %{current_frame: current_frame, output_func: output_func} = state
      ) do
    end_frames = current_frame + requested_frames - 1
    send_frames(output_func.(current_frame..end_frames))

    {:noreply, %{state | current_frame: end_frames + 1}}
  end

  @impl true
  @spec handle_info({:sample_rate, pos_integer()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:sample_rate, sample_rate},
        state
      ) do
    Logger.debug("JACK Event: Sample rate updated #{sample_rate}")
    {:noreply, %{state | sample_rate: sample_rate}}
  end

  @impl true
  @spec handle_info({:ports_connected, String.t(), String.t()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:ports_connected, port_name_a, port_name_b},
        %{ports: ports} = state
      ) do
    Logger.debug("JACK Event: Ports connected #{port_name_a} #{port_name_b}")

    ports =
      update_in(ports, [Access.key!(port_name_a), :connections], &MapSet.put(&1, port_name_b))

    {:noreply, %{state | ports: ports}}
  end

  @impl true
  @spec handle_info({:ports_disconnected, String.t(), String.t()}, t()) ::
          {:noreply, __MODULE__.t()}
  def handle_info(
        {:ports_disconnected, port_name_a, port_name_b},
        %{ports: ports} = state
      ) do
    Logger.debug("JACK Event: Ports disconnected #{port_name_a} #{port_name_b}")

    ports =
      update_in(ports, [Access.key!(port_name_a), :connections], &MapSet.delete(&1, port_name_b))

    {:noreply, %{state | ports: ports}}
  end

  @impl true
  @spec handle_info(:xrun, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        :xrun,
        state
      ) do
    Logger.debug("JACK Event: XRUN occured")
    {:noreply, state}
  end

  @impl true
  @spec handle_info({:port_register, String.t()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:port_register, port_id, port_name},
        %{ports: ports} = state
      ) do
    Logger.debug("JACK Event: Port registered #{port_id} #{port_name}")

    [client_name, short_name] = String.split(port_name, ":")

    ports =
      Map.put(ports, port_name, %{
        connections: MapSet.new(),
        name: short_name,
        client: client_name
      })

    {:noreply, %{state | ports: ports}}
  end

  @impl true
  @spec handle_info({:port_unregister, String.t()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:port_unregister, port_name},
        %{ports: ports} = state
      ) do
    Logger.debug("JACK Event: Port unregistered #{port_name}")

    ports = Map.delete(ports, port_name)

    ports =
      for {key, %{connections: connections} = val} <- ports, into: %{} do
        if MapSet.member?(connections, port_name) do
          {key,
           %{
             val
             | connections: MapSet.delete(connections, port_name)
           }}
        else
          {key, val}
        end
      end

    {:noreply, %{state | ports: ports}}
  end

  @impl true
  @spec handle_info({:client_register, String.t()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:client_register, client_id},
        %{clients: clients} = state
      ) do
    Logger.debug("JACK Event: Client registered #{client_id}")
    {:noreply, %{state | clients: MapSet.put(clients, client_id)}}
  end

  @impl true
  @spec handle_info({:client_unregister, String.t()}, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        {:client_unregister, client_id},
        state
      ) do
    Logger.debug("JACK Event: Client unregistered #{client_id}")

    {:noreply, state}
  end

  @impl true
  @spec handle_info(:shutdown, t()) :: {:noreply, __MODULE__.t()}
  def handle_info(
        :shutdown,
        state
      ) do
    Logger.debug("JACK Event: Shutting down")

    {:stop, :normal, state}
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
