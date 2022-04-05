defmodule IoEffects.Buffer do
  use GenServer

  def start_link(default \\ []) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  def flush(length) do
    GenServer.call(__MODULE__, {:flush, length})
  end

  def store(values) do
    GenServer.cast(__MODULE__, {:store, values})
  end

  def size() do
    GenServer.call(__MODULE__, :size)
  end


  @impl true
  def init(initial_buffer) do
    {:ok, initial_buffer}
  end

  @impl true
  def handle_call(:size, _from, state) do
    {:reply, Enum.count(state), state}
  end

  @impl true
  def handle_call({:flush, length}, _from, state) do
    {:reply, Enum.take(state, length), Enum.drop(state, length)}
  end

  @impl true
  def handle_cast({:store, buffer}, state) do
    {:noreply, state ++ buffer}
  end
end

