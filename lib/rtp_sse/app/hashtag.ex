defmodule App.Hashtag do
  @moduledoc """
  Usage:
  print hashtags statistics to the terminal
      iex> RTP_SSE.HashtagsWorker.show_stats

  save hashtags statistics as `JSON` (file `hashtag_stats.json`)
      iex> RTP_SSE.HashtagsWorker.download_stats
  """
  @flush_time 3000 # save hashtags to JSON every 3 sec

  use GenServer
  require Logger

  def start_link(_args, opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  ## Client API

  @doc """
  If the tweet has some tags it will add in our state map
  and update tag occurrence respectively
  """
  def process_hashtags(pid, tweet) do
    GenServer.cast(pid, {:process_hashtags, tweet})
  end

  @doc """
  Display the sorted tag statistics
  """
  def show_stats(pid) do
    GenServer.cast(pid, {:show_stats})
  end

  @doc """
  Saves the hashtags statistics in JSON file `hashtag_stats.json`
  """
  def download_stats(pid) do
    GenServer.cast(pid, {:download_stats})
  end

  ## Privates

  defp download_hashtags_loop() do
    # Will constantly save tweets & users into database in a 3 sec timeframe,
    # using only the @max_batch_size will produce data loss if the last
    # batch has less elements then our max size
    selfPID = self()
    spawn(
      fn ->
        Process.sleep(@flush_time)
        App.Hashtag.download_stats(selfPID)
      end
    )
  end

  ## Callbacks

  @impl true
  def init(state) do
    download_hashtags_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:download_stats}, stats) do
    sorted =
      stats
      |> Map.to_list()
      |> Enum.sort(fn {_k1, val1}, {_k2, val2} -> val1 <= val2 end)

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
    download_hashtags_loop()
    {:noreply, stats}
  end

  @impl true
  def handle_cast({:show_stats}, stats) do
    sorted =
      stats
      |> Map.to_list()
      |> Enum.sort(fn {_k1, val1}, {_k2, val2} -> val1 <= val2 end)

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
      hashtags_text =
        Enum.map(
          hashtags,
          fn x ->
            x["text"]
          end
        )

      stats =
        Enum.reduce(
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
