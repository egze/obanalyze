System.put_env("PHX_DASHBOARD_TEST", "PHX_DASHBOARD_ENV_VALUE")

Application.put_env(:obanalyze, Obanalyze.DashboardTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "QF9vsfJAwT1POSAZLc5sk4Rl4ZV5+fnxX7uos0cHZkT3P1tBQID3V5YsGQyDPKmT",
  live_view: [signing_salt: "QF9vsfJA"],
  render_errors: [view: Obanalyze.DashboardTest.ErrorView],
  check_origin: false,
  pubsub_server: Obanalyze.DashboardTest.PubSub
)

Application.put_env(:obanalyze, Obanalyze.DashboardTest.Repo,
  database: System.get_env("SQLITE_DB") || "test.db",
  migration_lock: false
)

defmodule Obanalyze.DashboardTest.Repo do
  use Ecto.Repo, otp_app: :obanalyze, adapter: Ecto.Adapters.SQLite3
end

_ = Ecto.Adapters.SQLite3.storage_up(Obanalyze.DashboardTest.Repo.config())

defmodule Obanalyze.DashboardTest.ErrorView do
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule Obanalyze.DashboardTest.Telemetry do
  import Telemetry.Metrics

  def metrics do
    [
      counter("phx.b.c"),
      counter("phx.b.d"),
      counter("ecto.f.g"),
      counter("my_app.h.i")
    ]
  end
end

defmodule Obanalyze.DashboardTest.Router do
  use Phoenix.Router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/", ThisWontBeUsed, as: :this_wont_be_used do
    pipe_through(:browser)

    # Ecto repos will be auto discoverable.
    live_dashboard("/dashboard",
      metrics: Obanalyze.DashboardTest.Telemetry,
      additional_pages: [
        obanalyze: Obanalyze.dashboard()
      ]
    )
  end
end

defmodule Obanalyze.DashboardTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :obanalyze

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger_param_key",
    cookie_key: "request_logger_cookie_key"
  )

  plug(Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "QF9vsfJA"
  )

  plug(Obanalyze.DashboardTest.Router)
end

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: Obanalyze.DashboardTest.PubSub, adapter: Phoenix.PubSub.PG2},
    Obanalyze.DashboardTest.Repo,
    Obanalyze.DashboardTest.Endpoint,
    {Oban, testing: :manual, engine: Oban.Engines.Lite, repo: Obanalyze.DashboardTest.Repo},
    {Ecto.Migrator,
     repos: [Obanalyze.DashboardTest.Repo],
     migrator: fn repo, :up, opts ->
       Ecto.Migrator.run(repo, Path.join([__DIR__, "support", "migrations"]), :up, opts)
     end}
  ],
  strategy: :one_for_one
)

ExUnit.start()
