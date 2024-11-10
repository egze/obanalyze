# Obanalyze

<!-- MDOC !-->

Real-time Monitoring for `Oban` with `Phoenix.LiveDashboard`.

## Install

The package can be installed by adding `obanalyze` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:obanalyze, "~> 1.0"}
  ]
end
```

## Configure

Update the `live_dashboard` configuration in your router.

```elixir
# lib/my_app_web/router.ex
live_dashboard "/dashboard",
  additional_pages: [
    obanalyze: Obanalyze.dashboard()
  ]
```

## Done

Go to your `Phoenix.LiveDashboard` and you should see the `Obanalyze` tab.

![Obanalyze screenshot](doc/images/obanalyze.png "Obanalyze")


# Alternatives

* [evilmarty/oban_live_dashboard](https://github.com/evilmarty/oban_live_dashboard) where I took my inspiration from.
 You should check it out if you want a simple way to observe your Oban jobs.
