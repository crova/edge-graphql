# EdgeGraphql
This Phoenix application uses [`Absinthe`](https://github.com/absinthe-graphql/absinthe) to handle the GraphQL implementation and [`Cachex`](https://github.com/whitfin/cachex) to deal with caching. GraphQL query results are fetched from [`Punk api`](https://punkapi.com/) using [`HTTPoison`](https://github.com/edgurgel/httpoison).
We can then deploy it to multiple regions with [`Fly`](https://fly.io) to cache queries closer to the user.

You also have a [`companion article`](https://github.com/crova/edge-graphql/blob/master/companion_article.md) where we talk about the reasons you might want to do something like this and some interest bits of this sample application.

# To run it locally:
  * Clone the repo
  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

      Now you can visit [`localhost:4000/`](http://localhost:4000/) from your browser and play with the available query.
      The following query is available to try it out:

      ```graphql
      {
        beers(name:"beer name") {
          name,
          abv,
          firstBrewed,
          foodPairing
        }
      }

      ```

# Deploy to Fly:
  * Create your account on [`Fly`](https://fly.io/)
  * Install [`flyctl`](https://fly.io/docs/getting-started/installing-flyctl/)
  * Create a Fly app: `flyctl apps create`
  * Change the `host` of your `config/prod.exs` to match your Fly app name. 
  * Deploy the app with `flyctl deploy`
  * You can navigate to `https://your-app.fly.dev/` and play around.

# Testing latency:
You can use `cURL` to see how long your requests are taking.
```
Punk API:
beer by name
curl 'https://api.punkapi.com/v2/beers?beer_name=Punk' \
-o /dev/null -sS \
-w "Timings\n------\ntotal:   %{time_total}\nconnect: %{time_connect}\ntls:     %{time_appconnect}\n"


GraphQL API:
beer by name:
curl 'https://<appname>.fly.dev/?variables=%7B%7D&query=%7B%0A%20%20beers(name%3A%22punk%22)%20%7B%0A%20%20%20%20name%2C%0A%20%20%20%20abv%2C%0A%20%20%20%20firstBrewed%2C%0A%20%20%20%20foodPairing%0A%20%20%7D%0A%7D' \
-o /dev/null -sS \
-X GET \
-H "Content-Type: application/json" \
-w "Timings\n------\ntotal:   %{time_total}\nconnect: %{time_connect}\ntls:     %{time_appconnect}\n"

``` 

You could also `flyctl logs` and check the response time from there.
# Some numbers:
|Hit on Source Api|seconds|
|-|-|
|total:|   0,296964|
|connect:| 0,123632|
|tls:|     0,218332|

|Hit on App - Uncached|seconds|
|-|-|
|total:|   0,628647|
|connect:| 0,066114|
|tls:|     0,324010|


|Hit on App - Cached|seconds|
|-|-|
|total:|   0,178687|
|connect:| 0,046614|
|tls:|     0,109855|
