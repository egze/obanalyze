defmodule Obanalyze.ObanJobs do
  import Ecto.Query, only: [group_by: 3, order_by: 2, order_by: 3, select: 3, limit: 2, where: 3]

  def get_oban_job(id) do
    Oban.Repo.get(Oban.config(), Oban.Job, id)
  end

  def list_jobs_with_total(params, job_state) do
    total_jobs = Oban.Repo.aggregate(Oban.config(), jobs_count_query(job_state), :count)

    jobs =
      Oban.Repo.all(Oban.config(), jobs_query(params, job_state)) |> Enum.map(&Map.from_struct/1)

    {jobs, total_jobs}
  end

  defp jobs_query(%{sort_by: sort_by, sort_dir: sort_dir, limit: limit}, job_state) do
    Oban.Job
    |> limit(^limit)
    |> where([job], job.state == ^job_state)
    |> order_by({^sort_dir, ^sort_by})
  end

  defp jobs_count_query(job_state) do
    Oban.Job
    |> where([job], job.state == ^job_state)
  end

  def job_states_with_count do
    Oban.Repo.all(
      Oban.config(),
      Oban.Job
      |> group_by([j], [j.state])
      |> order_by([j], [j.state])
      |> select([j], {j.state, count(j.id)})
    )
    |> Enum.into(%{})
  end

  def timestamp_field_for_job_state(job_state, default \\ :attempted_at) do
    case job_state do
      "available" -> :scheduled_at
      "cancelled" -> :cancelled_at
      "completed" -> :completed_at
      "discarded" -> :discarded_at
      "executing" -> :attempted_at
      "retryable" -> :scheduled_at
      "scheduled" -> :scheduled_at
      _ -> default
    end
  end
end
