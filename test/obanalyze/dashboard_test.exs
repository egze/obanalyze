defmodule Obanalyze.DashboardTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Obanalyze.DashboardTest.Endpoint

  setup do
    Obanalyze.DashboardTest.Repo.delete_all(Oban.Job)
    :ok
  end

  test "menu_link/2" do
    assert {:ok, "Obanalyze"} = Obanalyze.Dashboard.menu_link(nil, nil)
  end

  test "shows jobs with limit" do
    for _ <- 1..110, do: job_fixture(%{}, state: "executing", attempted_at: DateTime.utc_now())
    {:ok, live, rendered} = live(build_conn(), "/dashboard/obanalyze")
    assert_count(rendered, "executing", 20)

    rendered = render_patch(live, "/dashboard/obanalyze?limit=100")
    assert_count(rendered, "executing", 100)
  end

  test "shows job info modal" do
    job =
      job_fixture(%{something: "foobar"}, state: "executing", attempted_at: DateTime.utc_now())

    {:ok, live, rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")
    assert rendered =~ "modal-content"
    assert rendered =~ "foobar"

    refute live
           |> element("#modal-close")
           |> render_click() =~ "modal-close"
  end

  test "switch between states" do
    _executing_job =
      job_fixture(%{"foo" => "executing"}, state: "executing", attempted_at: DateTime.utc_now())

    _completed_job =
      job_fixture(%{"foo" => "completed"}, state: "completed", completed_at: DateTime.utc_now())

    conn = build_conn()
    {:ok, live, rendered} = live(conn, "/dashboard/obanalyze")

    assert_count(rendered, "executing", 1)

    {:ok, live, rendered} =
      live
      |> element("a", "Completed (1)")
      |> render_click()
      |> follow_redirect(conn)

    assert_count(rendered, "completed", 1)

    {:ok, _live, rendered} =
      live
      |> element("a", "Scheduled (0)")
      |> render_click()
      |> follow_redirect(conn)

    assert_count(rendered, "scheduled", 0)
  end

  test "run now job" do
    job = job_fixture(%{foo: "bar"}, schedule_in: 1000)
    {:ok, live, _rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")

    assert has_element?(live, "pre", "scheduled")
    element(live, "button", "Run now") |> render_click()
    assert has_element?(live, "pre", "available")
  end

  test "retry job" do
    job = job_fixture(%{foo: "bar"}, state: "cancelled")
    {:ok, live, _rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")

    assert has_element?(live, "pre", "cancelled")
    element(live, "button", "Retry") |> render_click()
    assert has_element?(live, "pre", "available")
  end

  test "cancel job" do
    job = job_fixture(%{foo: "bar"}, schedule_in: 1000)
    {:ok, live, _rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")

    assert has_element?(live, "pre", "scheduled")
    element(live, "button", "Cancel") |> render_click()
    assert has_element?(live, "pre", "cancelled")
  end

  test "delete job" do
    job = job_fixture(%{foo: "bar"}, schedule_in: 1000)
    {:ok, live, _rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")

    assert has_element?(live, "pre", "scheduled")
    element(live, "button", "Delete") |> render_click()
    assert_patched(live, "/dashboard/obanalyze?")
  end

  test "search" do
    _json_job =
      job_fixture(%{foo: "json"},
        state: "executing",
        worker: "JsonWorker",
        attempted_at: DateTime.utc_now()
      )

    _yaml_job =
      job_fixture(%{foo: "yaml"},
        state: "executing",
        worker: "YamlWorker",
        attempted_at: DateTime.utc_now()
      )

    {:ok, _live, rendered} = live(build_conn(), "/dashboard/obanalyze?search=JsonWorker")
    assert_count(rendered, 1)

    {:ok, _live, rendered} = live(build_conn(), "/dashboard/obanalyze?search=YamlWorker")
    assert_count(rendered, 1)

    {:ok, _live, rendered} = live(build_conn(), "/dashboard/obanalyze?search=yamlworker")
    assert_count(rendered, 1)

    {:ok, _live, rendered} = live(build_conn(), "/dashboard/obanalyze?search=foo")
    assert_count(rendered, 2)

    {:ok, _live, rendered} = live(build_conn(), "/dashboard/obanalyze?search=nothing")
    assert_count(rendered, 0)
  end

  defp assert_count(rendered, state \\ "executing", n) do
    assert length(:binary.matches(rendered, "<td class=\"oban-jobs-#{state}-worker\"")) == n
  end

  defp job_fixture(args, opts) do
    opts = Keyword.put_new(opts, :worker, "FakeWorker")
    {:ok, job} = Oban.Job.new(args, opts) |> Oban.insert()
    job
  end
end
