defmodule Obanalyze.ObanJobs do
  import Ecto.Query,
    only: [from: 2, group_by: 3, order_by: 2, order_by: 3, select: 3, limit: 2, where: 3]

  @oban_name Application.compile_env(:obanalyze, :oban_name, Oban)

  defp oban_config(), do: Oban.config(@oban_name)

  def get_oban_job(job_id) do
    Oban.Repo.get(oban_config(), Oban.Job, job_id)
  end

  def fetch_oban_job(job_id) do
    case get_oban_job(job_id) do
      %Oban.Job{} = job -> {:ok, job}
      _ -> {:error, :not_found}
    end
  end

  def delete_oban_job(job_id) do
    query = from(oj in Oban.Job, where: oj.id in [^job_id])
    Oban.Repo.delete_all(oban_config(), query)
    :ok
  end

  def retry_oban_job(job_id) do
    with {:ok, job} <- fetch_oban_job(job_id),
         :ok <- Oban.Engine.retry_job(oban_config(), job),
         {:ok, job} <- fetch_oban_job(job_id) do
      {:ok, job}
    end
  end

  def cancel_oban_job(job_id) do
    with {:ok, job} <- fetch_oban_job(job_id),
         :ok <- Oban.Engine.cancel_job(oban_config(), job),
         {:ok, job} <- fetch_oban_job(job_id) do
      {:ok, job}
    end
  end

  def list_jobs_with_total(params, job_state) do
    total_jobs = Oban.Repo.aggregate(oban_config(), jobs_count_query(job_state), :count)

    jobs =
      Oban.Repo.all(oban_config(), jobs_query(params, job_state)) |> Enum.map(&Map.from_struct/1)

    {jobs, total_jobs}
  end

  defp jobs_query(%{sort_by: sort_by, sort_dir: sort_dir, limit: limit} = params, job_state) do
    Oban.Job
    |> limit(^limit)
    |> where([job], job.state == ^job_state)
    |> order_by({^sort_dir, ^sort_by})
    |> filter(params[:search])
  end

  defp filter(query, nil), do: query

  defp filter(query, term) do
    like = "%#{term}%"

    if postgres?() do
      from oj in query,
        where: ilike(oj.worker, ^like),
        or_where: ilike(type(oj.args, :string), ^like)
    else
      from oj in query,
        where: like(oj.worker, ^like),
        or_where: like(type(oj.args, :string), ^like)
    end
  end

  defp postgres? do
    oban_config().engine in [Oban.Engines.Basic, Oban.Pro.Engines.Smart]
  end

  defp jobs_count_query(job_state) do
    Oban.Job
    |> where([job], job.state == ^job_state)
  end

  def job_states_with_count do
    Oban.Repo.all(
      oban_config(),
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

  def sorted_job_states do
    [
      "executing",
      "available",
      "scheduled",
      "retryable",
      "cancelled",
      "discarded",
      "completed"
    ]
  end
end
