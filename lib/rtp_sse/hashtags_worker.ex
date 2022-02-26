defmodule RTP_SSE.HashtagsWorker do

  use GenServer
  require Logger

  @impl true
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  ## Client API

  @doc """
  If the tweet has some tags it will add in our state map
  and update tag occurrence respectively
  """
  def process_hashtags(tweet) do
    GenServer.cast(__MODULE__, {:process_hashtags, tweet})
  end

  @doc """
  Display the sorted tag statistics
  """
  def show_stats() do
    GenServer.cast(__MODULE__, {:show_stats})
  end

  @doc """
  Saves the hashtags statistics in JSON file `hashtag_stats.json`
  """
  def download_stats() do
    GenServer.cast(__MODULE__, {:download_stats})
  end

  ## Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:download_stats}, stats) do
    sorted
    = stats
      |> Map.to_list
      |> Enum.sort(fn ({_k1, val1}, {_k2, val2}) -> val1 <= val2 end)
    {:ok, file} = File.open("hashtag_stats.json", [:write])

    file
    |> :file.position(:bof)
    |> :file.truncate()

    IO.binwrite(file, "{\r\n")

    sorted
    |> Enum.with_index()
    |> Enum.each(
         fn {{tag, occurrence}, index} ->
           # remove last element comma in JSON
           if index == length(sorted) - 1 do
             IO.binwrite(file, '\t"#{tag}": #{occurrence}\r\n')
           else
             IO.binwrite(file, '\t"#{tag}": #{occurrence},\r\n')
           end
         end
       )

    IO.binwrite(file, "}")
    {:noreply, stats}
  end

  @impl true
  def handle_cast({:show_stats}, stats) do
    sorted
    = stats
      |> Map.to_list
      |> Enum.sort(fn ({_k1, val1}, {_k2, val2}) -> val1 <= val2 end)
    Enum.each(
      sorted,
      fn {tag, occurrence} ->
        Logger.info("Tag: #{tag} - Occurrence: #{occurrence}")
      end
    )
    {:noreply, stats}
  end

  @impl true
  def handle_cast({:process_hashtags, tweet}, state) do
    {:ok, json} = Poison.decode(tweet)
    hashtags = json["message"]["tweet"]["entities"]["hashtags"]
    if length(hashtags) > 0 do
      hashtags_text = Enum.map(
        hashtags,
        fn x ->
          x["text"]
        end
      )
      stats = Enum.reduce(
        hashtags_text,
        state,
        fn tag, acc ->
          if Map.has_key?(state, tag) do
            Map.put(acc, tag, Map.get(state, tag) + 1)
          else
            Map.put(acc, tag, 0)
          end
        end
      )
      {:noreply, stats}
    else
      {:noreply, state}
    end
  end


end