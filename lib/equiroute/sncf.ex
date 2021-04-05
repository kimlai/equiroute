defmodule Equiroute.Sncf do
  alias Plug.Conn.Query

  @base_url "https://api.sncf.com/v1/coverage/sncf"

  def find_place(query) do
    query_params = [
      q: query,
      type: ["administrative_region"]
    ]

    case send_request("/places", query_params) do
      {:ok, %{"places" => places}} ->
        for place <- places, into: [] do
          %{
            name: place["name"],
            sncf_id: place["administrative_region"]["id"]
          }
        end

      {:error, _} ->
        "priv/sncf_data/administrative_regions"
        |> File.read!()
        |> :erlang.binary_to_term()
        |> Enum.filter(&String.contains?(String.downcase(&1["name"]), String.downcase(query)))
        |> Enum.map(&Map.put(&1, :sncf_id, &1["id"]))
        |> Enum.map(&Map.put(&1, :name, &1["label"]))
    end
  end

  def place(id) do
    place =
      case send_request("/places/#{id}") do
        {:ok, %{"places" => [place | []]}} ->
          %{
            name: String.replace(place["name"], ~r/\s*\(.*?\)\s*/, ""),
            coordinates: [
              place["administrative_region"]["coord"]["lon"],
              place["administrative_region"]["coord"]["lat"]
            ],
            sncf_id: place["administrative_region"]["id"]
          }

        {:error, _} ->
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
