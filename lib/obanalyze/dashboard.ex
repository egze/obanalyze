defmodule Obanalyze.Dashboard do
  @moduledoc false

  use Phoenix.LiveDashboard.PageBuilder, refresher?: true

  import Phoenix.LiveDashboard.Helpers, only: [format_value: 2]

  alias Obanalyze.ObanJobs

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
        <.live_table id="oban_jobs" limit={per_page_limits()} dom_id={"oban-jobs-#{nav_item.name}"} page={@page} row_attrs={&row_attrs/1} row_fetcher={&row_fetcher(&1, &2, nav_item.name)} default_sort_by={@default_sort_by} title="" search={false}>
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
        %Oban.Job{id: job_id} -> ObanJobs.get_oban_job(job_id)
        _ -> nil
      end)

    {:noreply, socket}
  end

  defp assign_job(socket, job_id) do
    if job_id do
      case ObanJobs.get_oban_job(job_id) do
        %Oban.Job{} = job ->
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
    assign(socket, nav_items: Obanalyze.get_nav_items())
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
end
