defmodule EdgeGraphqlWeb.Schema do
  use Absinthe.Schema

  alias EdgeGraphqlWeb.BeersResolver

  query do
    @desc "Get a list of beers by name"
    field :beers, list_of(non_null(:beer)) do
      arg :name, non_null(:string)

      resolve(&BeersResolver.search_beers/3)
    end
  end

  object :beer do
    field :name, non_null(:string)
    field :first_brewed, non_null(:string)
    field :food_pairing, list_of(non_null(:string))
    field :abv, non_null(:float)
  end
end
