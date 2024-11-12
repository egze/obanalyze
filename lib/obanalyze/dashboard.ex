defmodule Obanalyze.Dashboard do
  @moduledoc false

  use Phoenix.LiveDashboard.PageBuilder, refresher?: true

  import Phoenix.LiveDashboard.Helpers, only: [format_value: 2]
  import Ecto.Query, only: [group_by: 3, order_by: 2, order_by: 3, select: 3, limit: 2, where: 3]

  alias Obanalyze.NavItem

  @per_page_limits [20, 50, 100]

  @oban_sorted_job_states [
    "executing",
    "available",
    "scheduled",
    "retryable",
    "cancelled",
    "discarded",
    "completed"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      #job-modal tr > :first-child {
        width: 20%;
      }
    </style>

    <h1 class="mb-3">Obanalyze</h1>

    <p>Filter jobs by state:</p>

    <.live_nav_bar id="oban_states" page={@page} nav_param="job_state" style={:bar} extra_params={["nav"]}>
      <:item :for={nav_item <- @nav_items} name={nav_item.name} label={nav_item.label} method="navigate">
        <.live_table id="oban_jobs" limit={per_page_limits()} dom_id={"oban-jobs-#{nav_item.name}"} page={@page} row_attrs={&row_attrs/1} row_fetcher={&fetch_jobs(&1, &2, nav_item.name)} default_sort_by={@default_sort_by} title="" search={false}>
          <:col :let={job} field={:worker} sortable={:desc}>
            <p class="font-weight-bold"><%= job.worker %></p>
            <pre class="font-weight-lighter text-muted"><%= truncate(inspect(job.args)) %></pre>
          </:col>
          <:col :let={job} field={:attempt} header="Attempt" sortable={:desc}>
            <%= job.attempt %>/<%= job.max_attempts %>
          </:col>
          <:col field={:queue} header="Queue" sortable={:desc} />
          <:col :let={job} field={nav_item.timestamp_field} sortable={:desc}>
            <%= format_value(timestamp(job, nav_item.timestamp_field)) %>
          </:col>
        </.live_table>
      </:item>
    </.live_nav_bar>

    <.live_modal :if={@job != nil} id="job-modal" title={"Job - #{@job.id}"} return_to={live_dashboard_path(@socket, @page, params: %{})}>
      <.label_value_list>
        <:elem label="ID"><%= @job.id %></:elem>
        <:elem label="State"><%= @job.state %></:elem>
        <:elem label="Queue"><%= @job.queue %></:elem>
        <:elem label="Worker"><%= @job.worker %></:elem>
        <:elem label="Args"><%= format_value(@job.args, nil) %></:elem>
        <:elem :if={@job.meta != %{}} label="Meta"><%= format_value(@job.meta, nil) %></:elem>
        <:elem :if={@job.tags != []} label="Tags"><%= format_value(@job.tags, nil) %></:elem>
        <:elem :if={@job.errors != []} label="Errors"><%= format_errors(@job.errors) %></:elem>
        <:elem label="Attempts"><%= @job.attempt %>/<%= @job.max_attempts %></:elem>
        <:elem label="Priority"><%= @job.priority %></:elem>
        <:elem label="Attempted at"><%= format_value(@job.attempted_at) %></:elem>
        <:elem :if={@job.cancelled_at} label="Cancelled at"><%= format_value(@job.cancelled_at) %></:elem>
        <:elem :if={@job.completed_at} label="Completed at"><%= format_value(@job.completed_at) %></:elem>
        <:elem :if={@job.discarded_at} label="Discarded at"><%= format_value(@job.discarded_at) %></:elem>
        <:elem label="Inserted at"><%= format_value(@job.inserted_at) %></:elem>
        <:elem label="Scheduled at"><%= format_value(@job.scheduled_at) %></:elem>
      </.label_value_list>
    </.live_modal>
    """
  end

  @impl true
  def mount(_params, _, socket) do
    {:ok, socket}
  end

  @impl true
  def menu_link(_, _) do
    {:ok, "Obanalyze"}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign_nav_items()
      |> assign_default_sort_by(params["job_state"])
      |> assign_job(get_in(params, ["params", "job"]))

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_job", params, socket) do
    to = live_dashboard_path(socket, socket.assigns.page, params: params)
    {:noreply, push_patch(socket, to: to)}
  end

  @impl true
  def handle_refresh(socket) do
    socket =
      socket
      |> assign_nav_items()
      |> update(:job, fn
        %Oban.Job{id: job_id} -> get_job(job_id)
        _ -> nil
      end)

    {:noreply, socket}
  end

  defp assign_job(socket, job_id) do
    if job_id do
      case fetch_job(job_id) do
        {:ok, job} ->
          assign(socket, job: job)

        :error ->
          to = live_dashboard_path(socket, socket.assigns.page, params: %{})
          push_patch(socket, to: to)
      end
    else
      assign(socket, job: nil)
    end
  end

  defp assign_nav_items(socket) do
    job_state_counts = job_state_counts()

    nav_items =
      for job_state <- @oban_sorted_job_states,
          count = Map.get(job_state_counts, job_state, 0),
          timestamp_field = timestamp_field_for_job_state(job_state),
          do: NavItem.new(job_state, count, timestamp_field)

    assign(socket, nav_items: nav_items)
  end

  defp job_state_counts do
    Oban.Repo.all(
      Oban.config(),
      Oban.Job
      |> group_by([j], [j.state])
      |> order_by([j], [j.state])
      |> select([j], {j.state, count(j.id)})
    )
    |> Enum.into(%{})
  end

  defp fetch_jobs(params, _node, job_state) do
    total_jobs = Oban.Repo.aggregate(Oban.config(), jobs_count_query(job_state), :count)

    jobs =
      Oban.Repo.all(Oban.config(), jobs_query(params, job_state)) |> Enum.map(&Map.from_struct/1)

    {jobs, total_jobs}
  end

  defp get_job(id) do
    Oban.Repo.get(Oban.config(), Oban.Job, id)
  end

  defp fetch_job(id) do
    case get_job(id) do
      %Oban.Job{} = job ->
        {:ok, job}

      _ ->
        :error
    end
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

  defp row_attrs(job) do
    [
      {"phx-click", "show_job"},
      {"phx-value-job", job[:id]},
      {"phx-page-loading", true}
    ]
  end

  defp format_errors(errors) do
    Enum.map(errors, &Map.get(&1, "error"))
  end

  defp format_value(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_value(value), do: value

  defp timestamp(job, timestamp_field) do
    Map.get(job, timestamp_field)
  end

  defp assign_default_sort_by(socket, job_state) do
    timestamp_field = timestamp_field_for_job_state(job_state)

    assign(socket, :default_sort_by, timestamp_field)
  end

  defp timestamp_field_for_job_state(job_state) do
    case job_state do
      "available" -> :scheduled_at
      "cancelled" -> :cancelled_at
      "completed" -> :completed_at
      "discarded" -> :discarded_at
      "executing" -> :attempted_at
      "retryable" -> :scheduled_at
      "scheduled" -> :scheduled_at
      # because "executing" state is default
      _ -> :attempted_at
    end
  end

  defp truncate(string, max_length \\ 50) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "…"
    else
      string
    end
  end

  defp per_page_limits, do: @per_page_limits
end
