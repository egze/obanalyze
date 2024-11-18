defmodule Obanalyze.Dashboard do
  @moduledoc false

  use Phoenix.LiveDashboard.PageBuilder, refresher?: true

  import Phoenix.LiveDashboard.Helpers, only: [format_value: 2]
  import Obanalyze.Helpers

  alias Obanalyze.ObanJobs
  alias Obanalyze.NavItem

  @per_page_limits [20, 50, 100]

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
        <.live_table id="oban_jobs" limit={per_page_limits()} dom_id={"oban-jobs-#{nav_item.name}"} page={@page} row_attrs={&row_attrs/1} row_fetcher={&row_fetcher(&1, &2, nav_item.name)} default_sort_by={@default_sort_by} title="" search={true}>
          <:col field={:id} sortable={:desc} />
          <:col :let={job} field={:worker} sortable={:desc}>
            <p class="font-weight-bold"><%= job.worker %></p>
            <pre class="font-weight-lighter text-muted"><%= truncate(inspect(job.args)) %></pre>
          </:col>
          <:col :let={job} field={:attempt} header="Attempt" sortable={:desc}>
            <%= job.attempt %>/<%= job.max_attempts %>
          </:col>
          <:col field={:queue} header="Queue" sortable={:desc} />
          <:col :let={job} field={nav_item.timestamp_field} sortable={nav_item.default_timestamp_field_sort}>
            <span id={"job-ts-#{job.id}"} phx-update="ignore" data-timestamp={DateTime.to_unix(timestamp(job, nav_item.timestamp_field))} phx-hook="Relativize" title={format_value(timestamp(job, nav_item.timestamp_field))}><%= format_value(timestamp(job, nav_item.timestamp_field)) %></span>
          </:col>
        </.live_table>
      </:item>
    </.live_nav_bar>

    <.live_modal :if={@job != nil} id="job-modal" title={"Job - #{@job.id}"} return_to={live_dashboard_path(@socket, @page, params: %{})}>
      <div class="mb-4 btn-toolbar" role="toolbar" aria-label="Oban Job actions">
        <div :if={can_cancel_job?(@job)} class="btn-group" role="group">
          <button type="button" class="btn btn-primary btn-sm mr-2" phx-click="cancel_job" phx-value-job={@job.id} data-disable-with="Cancelling...">Cancel</button>
        </div>
        <div :if={can_run_job?(@job)} class="btn-group" role="group">
          <button type="button" class="btn btn-primary btn-sm mr-2" phx-click="retry_job" phx-value-job={@job.id} data-disable-with="Running...">Run now</button>
        </div>
        <div :if={can_retry_job?(@job)} class="btn-group" role="group">
          <button type="button" class="btn btn-primary btn-sm mr-2" phx-click="retry_job" phx-value-job={@job.id} data-disable-with="Retrying...">Retry</button>
        </div>
        <div :if={can_delete_job?(@job)} class="btn-group" role="group">
          <button type="button" class="btn btn-primary btn-sm mr-2" phx-click="delete_job" phx-value-job={@job.id} data-disable-with="Deleting..." data-confirm="Are you sure you want to delete this job?">Delete</button>
        </div>
      </div>
      <div class="tabular-info">
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
      </div>
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

  def handle_event("cancel_job", %{"job" => job_id}, socket) do
    with {:ok, job} <- ObanJobs.cancel_oban_job(job_id) do
      {:noreply, assign(socket, job: job)}
    end
  end

  def handle_event("retry_job", %{"job" => job_id}, socket) do
    with {:ok, job} <- ObanJobs.retry_oban_job(job_id) do
      {:noreply, assign(socket, job: job)}
    end
  end

  def handle_event("delete_job", %{"job" => job_id}, socket) do
    with :ok <- ObanJobs.delete_oban_job(job_id) do
      to = live_dashboard_path(socket, socket.assigns.page, params: %{})
      {:noreply, push_patch(socket, to: to)}
    end
  end

  @impl true
  def handle_refresh(socket) do
    socket =
      socket
      |> assign_nav_items()
      |> update(:job, fn
        %Oban.Job{id: job_id} -> ObanJobs.get_oban_job(job_id)
        _ -> nil
      end)

    {:noreply, socket}
  end

  defp assign_job(socket, job_id) do
    if job_id do
      case ObanJobs.fetch_oban_job(job_id) do
        {:ok, job} ->
          assign(socket, job: job)

        _ ->
          to = live_dashboard_path(socket, socket.assigns.page, params: %{})
          push_patch(socket, to: to)
      end
    else
      assign(socket, job: nil)
    end
  end

  defp assign_nav_items(socket) do
    assign(socket, nav_items: get_nav_items())
  end

  defp assign_default_sort_by(socket, job_state) do
    timestamp_field = ObanJobs.timestamp_field_for_job_state(job_state)

    assign(socket, :default_sort_by, timestamp_field)
  end

  defp row_fetcher(params, _node, job_state) do
    ObanJobs.list_jobs_with_total(params, job_state)
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

  defp truncate(string, max_length \\ 50) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "…"
    else
      string
    end
  end

  defp per_page_limits, do: @per_page_limits

  @doc """
  Returns the nav items to render the menu.
  """
  def get_nav_items do
    job_states_with_count = ObanJobs.job_states_with_count()

    for job_state <- ObanJobs.sorted_job_states(),
        count = Map.get(job_states_with_count, job_state, 0),
        timestamp_field = ObanJobs.timestamp_field_for_job_state(job_state),
        do: NavItem.new(job_state, count, timestamp_field)
  end
end
