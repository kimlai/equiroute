defmodule Equiroute.Http do
  def get_json(url) do
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

  def get_json!(url) do
    {:ok, response} = get_json(url)
    response
  end
end
