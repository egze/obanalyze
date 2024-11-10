defmodule Obanalyze.DashboardTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Obanalyze.DashboardTest.Endpoint

  test "menu_link/2" do
    assert {:ok, "Obanalyze"} = Obanalyze.Dashboard.menu_link(nil, nil)
  end

  test "shows jobs with limit" do
    for _ <- 1..110, do: job_fixture()
    {:ok, live, rendered} = live(build_conn(), "/dashboard/obanalyze")

    assert rendered |> :binary.matches("<td class=\"oban-jobs-executing-worker\"") |> length() ==
             20

    rendered = render_patch(live, "/dashboard/obanalyze?limit=100")

    assert rendered |> :binary.matches("<td class=\"oban-jobs-executing-worker\"") |> length() ==
             100
  end

  test "shows job info modal" do
    job = job_fixture(%{something: "foobar"})
    {:ok, live, _rendered} = live(build_conn(), "/dashboard/obanalyze?params[job]=#{job.id}")
    rendered = render(live)
    assert rendered =~ "modal-content"
    assert rendered =~ "%{&quot;something&quot; =&gt; &quot;foobar&quot;}"
    refute live |> element("#modal-close") |> render_click() =~ "modal"
  end

  defp job_fixture(args \\ %{}) do
    {:ok, job} =
      Oban.Job.new(args,
        worker: "FakeWorker",
        state: "executing",
        attempted_at: DateTime.utc_now()
      )
      |> Oban.insert()

    job
  end
end
