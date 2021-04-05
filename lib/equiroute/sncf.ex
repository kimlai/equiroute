defmodule Equiroute.Sncf do
  @token "6c5686c3-7106-4386-8b08-ddcb0e233d88"
  @base_url "https://api.sncf.com/v1/coverage/sncf"

  def find_place(query) do
    url = "#{@base_url}/places?q=#{query}&type[]=administrative_region&key=#{@token}"

    {:ok, %Finch.Response{body: body}} =
      Finch.build(:get, URI.encode(url)) |> Finch.request(MyFinch)

    %{"places" => places} = Jason.decode!(body)

    for place <- places, into: [] do
      %{
        name: place["name"],
        sncf_id: place["administrative_region"]["id"]
      }
    end
  end

  def place(id) do
    url = "#{@base_url}/places/#{id}?key=#{@token}"

    {:ok, %Finch.Response{body: body}} =
      Finch.build(:get, URI.encode(url)) |> Finch.request(MyFinch)

    %{"places" => [place | []]} = Jason.decode!(body)

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
    url = "#{@base_url}/journeys?from=#{from}&to=#{to}&key=#{@token}"

    {:ok, %Finch.Response{body: body}} =
      Finch.build(:get, URI.encode(url)) |> Finch.request(MyFinch)

    Jason.decode!(body)
    |> Map.get("journeys", [])
    |> Enum.map(& &1["durations"]["total"])
    |> Enum.min(fn -> nil end)
  end
end
