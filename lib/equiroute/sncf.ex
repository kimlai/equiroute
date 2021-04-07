defmodule Equiroute.Sncf do
  alias Plug.Conn.Query
  alias Equiroute.StringNormalize
  alias Equiroute.Http

  @base_url "https://api.sncf.com/v1/coverage/sncf"

  def find_place(query) do
    similarity = fn place ->
      String.jaro_distance(
        StringNormalize.normalize(place["name"]),
        StringNormalize.normalize(query)
      )
    end

    "priv/sncf_data/administrative_regions"
    |> File.read!()
    |> :erlang.binary_to_term()
    |> Enum.filter(&(similarity.(&1) > 0.9))
    |> Enum.sort_by(&similarity.(&1), :desc)
    |> Enum.map(&Map.put(&1, :sncf_id, &1["id"]))
    |> Enum.map(&Map.put(&1, :name, &1["name"]))
  end

  def find_closest(coordinates) do
    "priv/sncf_data/administrative_regions"
    |> File.read!()
    |> :erlang.binary_to_term()
    |> Enum.map(&Map.put(&1, :sncf_id, &1["id"]))
    |> Enum.map(&Map.put(&1, :name, &1["name"]))
    |> Enum.map(&Map.put(&1, :distance, harvesine(&1["coord"], coordinates)))
    |> Enum.filter(&(&1.distance < 50))
    |> Enum.sort_by(& &1.distance)
    |> Enum.take(5)
  end

  # https://github.com/acmeism/RosettaCodeData/blob/9ad63ea473a958506c041077f1d810c0c7c8c18d/Task/Haversine-formula/Elixir/haversine-formula.elixir
  defp harvesine(%{"lat" => lat1, "lon" => long1}, [long2, lat2]) do
    {lat1, _} = Float.parse(lat1)
    {long1, _} = Float.parse(long1)
    v = :math.pi() / 180
    r = 6372.8

    dlat = :math.sin((lat2 - lat1) * v / 2)
    dlong = :math.sin((long2 - long1) * v / 2)
    a = dlat * dlat + dlong * dlong * :math.cos(lat1 * v) * :math.cos(lat2 * v)
    r * 2 * :math.asin(:math.sqrt(a))
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
    case send_request("/journeys", from: from, to: to, datetime: tomorrow_at_7am()) do
      {:ok, response} ->
        response
        |> Map.get("journeys", [])
        |> Enum.map(& &1["durations"]["total"])
        |> Enum.min(fn -> nil end)

      {:error, _} ->
        nil
    end
  end

  defp tomorrow_at_7am do
    Date.utc_today()
    |> DateTime.new!(Time.new!(7, 0, 0), "Europe/Paris")
    |> DateTime.to_iso8601()
  end

  def all_administrative_regions() do
    "/stop_areas"
    |> build_url(count: 1000)
    |> all_administrative_regions()
  end

  def all_administrative_regions(url) do
    %{"links" => links, "stop_areas" => stop_areas} = Http.get_json!(url)

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
    |> Http.get_json()
  end
end
