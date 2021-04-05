defmodule Equiroute.Sncf do
  alias Plug.Conn.Query

  @base_url "https://api.sncf.com/v1/coverage/sncf"

  def find_place(query) do
    query_params = [
      q: query,
      type: ["administrative_region"]
    ]

    %{"places" => places} = send_request("/places", query_params)

    for place <- places, into: [] do
      %{
        name: place["name"],
        sncf_id: place["administrative_region"]["id"]
      }
    end
  end

  def place(id) do
    %{"places" => [place | []]} = send_request("/places/#{id}")

    %{
      name: String.replace(place["name"], ~r/\s*\(.*?\)\s*/, ""),
      coordinates: [
        place["administrative_region"]["coord"]["lon"],
        place["administrative_region"]["coord"]["lat"]
      ],
      sncf_id: place["administrative_region"]["id"]
    }
  end

  def journey_duration(from, to) do
    "/journeys"
    |> send_request(from: from, to: to)
    |> Map.get("journeys", [])
    |> Enum.map(& &1["durations"]["total"])
    |> Enum.min(fn -> nil end)
  end

  def all_administrative_regions() do
    "/stop_areas"
    |> build_url(count: 1000)
    |> all_administrative_regions()
  end

  def all_administrative_regions(url) do
    %{"links" => links, "stop_areas" => stop_areas} = get_json(url)

    administrative_regions =
      stop_areas
      |> Enum.filter(&Map.has_key?(&1, "administrative_regions"))
      |> Enum.map(&Enum.at(&1["administrative_regions"], 0))

    case Enum.find(links, &(&1["type"] == "next")) do
      nil ->
        administrative_regions

      %{"href" => url} ->
        [administrative_regions | all_administrative_regions(url)]
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
    {:ok, %Finch.Response{body: body}} = Finch.build(:get, url) |> Finch.request(MyFinch)
    Jason.decode!(body)
  end
end
