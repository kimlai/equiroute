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

  defp send_request(url, query_params \\ []) do
    token = System.get_env("SNCF_TOKEN")
    params = Query.encode(query_params ++ [key: token])
    url = "#{@base_url}#{url}?#{params}"

    {:ok, %Finch.Response{body: body}} = Finch.build(:get, url) |> Finch.request(MyFinch)

    Jason.decode!(body)
  end
end
