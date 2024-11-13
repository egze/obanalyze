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
    for _ <- 1..110, do: job_fixture(%{}, state: "executing")
    {:ok, live, rendered} = live(build_conn(), "/dashboard/obanalyze")

    assert rendered |> :binary.matches("<td class=\"oban-jobs-executing-worker\"") |> length() ==
             20

    rendered = render_patch(live, "/dashboard/obanalyze?limit=100")

    assert rendered |> :binary.matches("<td class=\"oban-jobs-executing-worker\"") |> length() ==
             100
  end

  test "shows job info modal" do
    job = job_fixture(%{something: "foobar"}, state: "executing")
    {:ok, live, rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")
    assert rendered =~ "modal-content"
    assert rendered =~ "foobar"

    refute live
           |> element("#modal-close")
           |> render_click() =~ "modal-close"
  end

  test "switch between states" do
    _executing_job = job_fixture(%{"foo" => "executing"}, state: "executing")
    _completed_job = job_fixture(%{"foo" => "completed"}, state: "completed")

    conn = build_conn()
    {:ok, live, rendered} = live(conn, "/dashboard/obanalyze")

    assert rendered |> :binary.matches("<td class=\"oban-jobs-executing-worker\"") |> length() ==
             1

    {:ok, live, rendered} =
      live
      |> element("a", "Completed (1)")
      |> render_click()
      |> follow_redirect(conn)

    assert rendered
           |> :binary.matches("<td class=\"oban-jobs-completed-worker\"")
           |> length() == 1

    {:ok, _live, rendered} =
      live
      |> element("a", "Scheduled (0)")
      |> render_click()
      |> follow_redirect(conn)

    assert rendered
           |> :binary.matches("<td class=\"oban-jobs-scheduled-worker\"")
           |> length() == 0
  end

  defp job_fixture(args, opts) do
    opts = Keyword.put_new(opts, :worker, "FakeWorker")
    {:ok, job} = Oban.Job.new(args, opts) |> Oban.insert()
    job
  end
end
