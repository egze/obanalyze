defmodule Obanalyze do
  @external_resource Path.expand("./README.md")
  @moduledoc File.read!(Path.expand("./README.md"))
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)
             |> String.replace("doc/images", "images")

  alias Obanalyze.ObanJobs
  alias Obanalyze.NavItem

  @oban_sorted_job_states [
    "executing",
    "available",
    "scheduled",
    "retryable",
    "cancelled",
    "discarded",
    "completed"
  ]

  @doc """
  Returns the module for the Obanalyze Phoenix.LiveDashboard page.
  """
  def dashboard do
    Obanalyze.Dashboard
  end

  @doc """
  Returns the nav items to render the menu.
  """
  def get_nav_items do
    job_states_with_count = ObanJobs.job_states_with_count()

    for job_state <- @oban_sorted_job_states,
        count = Map.get(job_states_with_count, job_state, 0),
        timestamp_field = ObanJobs.timestamp_field_for_job_state(job_state),
        do: NavItem.new(job_state, count, timestamp_field)
  end
end
