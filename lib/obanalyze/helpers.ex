defmodule Obanalyze.Helpers do
  alias Oban.Job

  def can_cancel_job?(%Job{} = job) do
    job.state in ["available", "executing", "inserted", "retryable", "scheduled"]
  end

  def can_delete_job?(%Job{} = job) do
    job.state not in ["executing"]
  end

  def can_retry_job?(%Job{} = job) do
    job.state in ["cancelled", "completed", "discarded", "retryable"]
  end

  def can_run_job?(%Job{} = job) do
    job.state in ["inserted", "scheduled"]
  end
end
