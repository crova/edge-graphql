defmodule EdgeGraphql.PunkApi do
  @moduledoc """
  Defines interface to interact with Punk Api.
  """

  @base_url "https://api.punkapi.com/v2/beers/"

  @type name :: String.t()

  @spec search_beers(name()) :: map()
  def search_beers(name) do
    {_, response} =
      name
      |> build_search_request_url()
      |> HTTPoison.get()

    Poison.decode!(response.body) |> atomize()
  end
  defp build_search_request_url(name), do: @base_url <> "?beer_name=#{name}"

  defp atomize(beers) when is_list(beers) do
    for beer <- beers do
      beer |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    end
  end
  defp atomize(beer), do: beer |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
end
