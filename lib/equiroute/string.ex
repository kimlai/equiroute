defmodule Equiroute.StringNormalize do
  def normalize(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\W/u, "")
    |> String.downcase()
  end
end
