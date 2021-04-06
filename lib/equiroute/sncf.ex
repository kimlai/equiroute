defmodule Equiroute.Sncf do
  alias Plug.Conn.Query

  @base_url "https://api.sncf.com/v1/coverage/sncf"

  def find_place(query) do
    similarity = fn place ->
      String.jaro_distance(String.downcase(place["name"]), String.downcase(query))
    end

    "priv/sncf_data/administrative_regions"
    |> File.read!()
    |> :erlang.binary_to_term()
    |> Enum.filter(&(similarity.(&1) > 0.8))
    |> Enum.sort_by(&similarity.(&1), :desc)
    |> Enum.map(&Map.put(&1, :sncf_id, &1["id"]))
    |> Enum.map(&Map.put(&1, :name, &1["name"]))
  end

  def place(id) do
    region =
      "priv/sncf_data/administrative_regions"
      |> File.read!()
      |> :erlang.binary_to_term()
      |> Enum.find(&(&1["id"] == id))

    %{
      name: region["name"],
      coordinates: [
        region["coord"]["lon"],
        region["coord"]["lat"]
      ],
      sncf_id: region["id"]
    }
  end

  def journey_duration(from, to) do
    case send_request("/journeys", from: from, to: to) do
      {:ok, response} ->
        response
        |> Map.get("journeys", [])
        |> Enum.map(& &1["durations"]["total"])
        |> Enum.min(fn -> nil end)

      {:error, _} ->
        nil
    end
  end

  def all_administrative_regions() do
    "/stop_areas"
    |> build_url(count: 1000)
    |> all_administrative_regions()
  end

  def all_administrative_regions(url) do
    %{"links" => links, "stop_areas" => stop_areas} = get_json!(url)

    administrative_regions =
      stop_areas
      |> Enum.filter(&Map.has_key?(&1, "administrative_regions"))
      |> Enum.map(&Enum.at(&1["administrative_regions"], 0))

    case Enum.find(links, &(&1["type"] == "next")) do
      nil ->
        administrative_regions

      %{"href" => url} ->
        administrative_regions ++ all_administrative_regions(url)
    end
  end

  def random_administrative_regions(n) do
    regions =
      "priv/sncf_data/administrative_regions"
      |> File.read!()
      |> :erlang.binary_to_term()
      |> Enum.shuffle()
      |> Enum.take(n)
  end

  defp build_url(url, query_params) do
    token = System.get_env("SNCF_TOKEN")
    params = Query.encode(query_params ++ [key: token])
    "#{@base_url}#{url}?#{params}"
  end

  defp send_request(url, query_params \\ []) do
    url
    |> build_url(query_params)
    |> get_json()
  end

  defp get_json(url) do
    case ConCache.get(:equiroute_cache, url) do
      nil ->
        case do_get_json(url) do
          {:ok, response} ->
            ConCache.put(:equiroute_cache, url, {:ok, response})
            {:ok, response}

          error ->
            error
        end

      cached ->
        cached
    end
  end

  defp do_get_json(url) do
    Finch.build(:get, url)
    |> Finch.request(MyFinch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: 429}} ->
        {:error, :quota_limit_reached}

      _ ->
        {:error, :unknown}
    end
  end

  defp get_json!(url) do
    {:ok, response} = get_json(url)
    response
  end
end
