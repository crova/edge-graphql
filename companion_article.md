# Avoid slow GraphQL queries by caching them where they're needed
One of the most common ways to make your site or app faster is reaching for a CDN (*Content Delivery Network*). It's surely a valid approach but also comes with burdens. It is also pretty hard when you're trying to cache dynamic content. Here, traditional CDNs usually won't be able to provide many benefits. We're going to explore another path in this article. One that takes the idea of a CDN but applies it to your whole application (or a part of it) and caches what's needed, where it's needed - close to your users.

# Would you like some beer?
Say we're implementing a GraphQL API for BrewDog, one that exposes the awesome information we can find on [`their DIY catalog`](https://www.brewdog.com/uk/community/diy-dog). We have customers all around the world but our `origin` is located in Scotland. Needless to say that we'll have to cater to the needs of our fellow brewers that are located far from our main server. We want the API calls to be fast, so no one is ever left wondering if something went bad. In our naive example, we'll make sure that barred the first call made for a resource, all others will be the fastest possible by caching them where it makes sense. On a side note, we could also make sure that the `first call` would be astonishingly snappy, but that's a subject for another article.

# Here's the plan
We'll tackle the problem by [`wrapping an existing REST API`](https://graphql.org/blog/rest-api-graphql-wrapper/) which will then be available to our clients through our GraphQL endpoint. In this example, we'll use the [`Punk API`](https://punkapi.com/) which does the heavy-lifting of exposing the BrewDog's DIY catalog. Wrapping existing endpoints is a common situation for those wanting to get a taste for GraphQL's benefits without re-writing a whole project from the get-go.

A [sample repository](https://github.com/crova/edge-graphql) is available so you can fiddle and test this idea yourself. 
Our application exposes an endpoint where you can query any BrewDog beer ever made with a given term and get some interesting facts about them, like which food they pair with.

Before issuing a request to Punk API, we'll check our app cache to see if we know the answer to the query. If that's the case, we promptly return the information. Otherwise, we'll ask the origin for the answer, and then cache it for subsequent requests. So far, nothing exciting.

# What's the trick?
The described plan looks pretty common until here, but since we'll have apps running in multiple regions, we'll be looking for a cached answer from the closest location to the current client. Much like a CDN, but not necessarily for a static resource. 

What's nice in our case is that, with the help of `Fly` hosting, we'll only cache it on the edge location that's being asked about it.
For instance, someone in New Zealand asks for beers with `stars` on their names. Since we just booted the app, we'll fetch the information from our `origin` in Europe. But when our kiwi friend tells about this awesome beer that he found out to his mate in the Gold Coast of Australia, and the bloke wants to check it out, we'll answer from our cache in Sidney and let the `origin` chill. Also, if no one in the Americas ever asks for this same information, there is no need for the node in Santiago or Chicago to ever cache this information. No resource shall be wasted.

# One tech is all we need
Our application is built with [Elixir](https://elixir-lang.org/) and [Phoenix](https://phoenixframework.org/). We're also using the amazing library called [`Absinthe`](http://absinthe-graphql.org/) for GraphQL implementation, [`Cachex`](https://github.com/whitfin/cachex) to do caching, [`HTTPoison`](https://github.com/edgurgel/httpoison) to handle HTTP requests and [`Fly's`](https://fly.io) multi-region, ease to deploy, service to spin a couple of copies of our application to multiple edge locations. By the time we're done, you might realize that you don't need a traditional CDN at all.

We don't need to deal with Apollo or [`their never-ending list of dependencies`](https://httptoolkit.tech/blog/simple-graphql-server-without-apollo/_) nor any other GraphQL client like `Relay`. If your front-end or IoT devices need to talk with your server, you can easily handle their exchanges with Phoenix and Elixir.

We'll assume that you have some basic knowledge of Elixir, GraphQL, and beers :) If you want to know more about Elixir check their [getting started](https://elixir-lang.org/getting-started/introduction.html) tutorial. You can also follow [Absinthe's first run guide](https://www.howtographql.com/graphql-elixir/0-introduction/) if that's your gap. And for the sake of completeness, [here is the Phoenix](https://hexdocs.pm/phoenix/up_and_running.html) initial walk-through.
Now let's get this party started!

# The GraphQL implementation with a sip of Absinthe
I know, we're talking about beers here, but I'm not the one making the names. We're going to wrap our source API (which is a REST one) and to offer an endpoint that answers queries about BrewDog's catalog, we'll need a few things. Since GraphQL enforces a `schema-driven development`, that's where we'll begin.
Our schema will simply implement `a beer object` and a `query`. [It will look something like this](https://github.com/crova/edge-graphql/blob/master/lib/edge_graphql_web/schema.ex):
```elixir
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
```
Using Absinthe's DSL, we defined an `object` block with its fields and types. Absinthe is [smart enough](https://github.com/absinthe-graphql/absinthe#idiomatic-documents-idiomatic-code) to convert the idiomatic Elixir `snake_case` notation into `camelCase`. Right below, we define our `query` which returns a list of the previous `beer` object and that accepts a `name` as the argument. We seal the deal by calling the function `search_beers/3` from the aliased module `BeersResolver` with the macro `resolve`. A resolver is nothing more than a function capable of handling our types and their fields. This is what tells your server what to do when a query arrives. [`They're also trivial (at least in our case) to implement`](https://github.com/crova/edge-graphql/blob/master/lib/edge_graphql_web/resolvers/beers_resolver.ex).
```elixir
# lib/edge_graphql_web/resolvers/beers_resolver.ex
defmodule EdgeGraphqlWeb.BeersResolver do
  @moduledoc false

  alias EdgeGraphql.Beers

  @type root :: map()
  @type args :: map()
  @type info :: map()

  @doc """
  Return a list of beers by name.
  If results were cached, will serve the cached answer. 
  Otherwise, will fetch from Punk and cache it for subsequent queries.
  """
  @spec search_beers(root(), args(), info()) :: {atom(), list()}
  def search_beers(_root, %{name: name}, _info) do
    case Cachex.get!(:graphql, "beer:#{name}") do
      nil ->
        beers = Beers.search_beers(name)
        Cachex.put(:graphql, "beer:#{name}", beers)
        {:ok, beers}
      beers ->
        {:ok, beers}
    end
  end
end
```
Our resolver calls the module [`Beers`](https://github.com/crova/edge-graphql/blob/master/lib/edge_graphql/beers.ex) that knows how to talk with the data source we're using on this example. The resolver will either return a tuple with the atom `:ok` and a list of `beers` or an empty list.
And there you go, everything we needed to make our system run is in place. You could run the app and try it out, but one last word on our `Resolver`. 

# A word on our cache system
If you look again at our [`resolver`](https://github.com/crova/edge-graphql/blob/master/lib/edge_graphql_web/resolvers/beers_resolver.ex#L17-L20), you'll notice that we're evaluating our cache table before asking the API wrapper for a result. For such a simple case like this, we could have simply thrown our query results into an [ets table](https://elixir-lang.org/getting-started/mix-otp/ets.html) and call it a day. But if you ever asked someone about how to roll your own caching, you probably heard "don't do it". So we're reaching for Cachex (that uses `ets` behind the scenes) to implement a simple caching mechanism for our `resolver`.

The cache implementation is pretty straightforward. When someone issues a query and our `BeersResolver` gets called, we check for an entry with the given `name` within the `:graphql` cache table. If nothing is found, we fetch from the source API. If we do find an entry, we simply return it. And since we know that our data won't change from year to year (when a new catalog is released) we can get away without any expiration time.

# The last touch
Now our simple system is in place and [if you fire up your app and visit it](https://github.com/crova/edge-graphql#to-run-it-locally), you can try out a query like `{ beers(name:"elixir") { name, abv, firstBrewed, foodPairing } }`. However, we're still running it locally. What about that talk of running it everywhere? 

The last piece of the puzzle is reaching for [Fly](https://fly.io). You give them a Docker image of your application, tell them where in the world you want copies and of you go.
Once everything is running, you have your GraphQL API deployed seamlessly in the regions of your choice, all without leaning on complicated DevOps flow.

# Where can you go from here
In this simple example, we dealt with a [`common use-case`](https://www.apollographql.com/blog/courseras-journey-to-graphql-a5ad3b77f39a) which involves wrapping an existing REST API. It could be that you're trying to solve `over/under fetching` for your APIs, much like the [`folks from Facebook`](https://engineering.fb.com/2015/09/14/core-data/graphql-a-data-query-language/) when they developed GraphQL (amongst other problems). Or maybe you're developing IoT devices with [`Nerves`](https://www.nerves-project.org/) and lowering bandwidth usage is paramount for your project. 

Perhaps you're having a hard time with your APIs versioning since your Flutter/React app requirements keep changing all the time. There is also the possibility that you already have a GraphQL API implemented but now is looking for solutions to scale it across many nodes and regions. 

Whatever may be your needs, hopefully, this article brought some insights into how you could apply some of the techniques and technologies we presented here in your daily endeavors.

# Wrapping up
One of the biggest selling points of Elixir is that you can achieve a lot with what's on offer within the standard libraries and the ecosystem around it.
Our sample application, even though is a really simple one, is an example of this power: we implemented a GraphQL server capable of handling incoming requests and issuing responses, talk to our REST API data source, as well as caching the results in-memory all without reaching for external tools.
Pairing Elixir with interesting techs like Fly can open up the possibilities on how to solve some of the issues that `scaling` and `globalization` present in our digital world.
