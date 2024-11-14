defmodule Obanalyze.NavItem do
  defstruct [:name, :label, :timestamp_field, :default_timestamp_field_sort]

  def new(state, count, timestamp_field) do
    %__MODULE__{
      name: state,
      label: "#{Phoenix.Naming.humanize(state)} (#{count})",
      timestamp_field: timestamp_field,
      default_timestamp_field_sort: if(timestamp_field == :scheduled_at, do: :asc, else: :desc)
    }
  end
end
