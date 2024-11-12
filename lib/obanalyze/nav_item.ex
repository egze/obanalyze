defmodule Obanalyze.NavItem do
  defstruct [:name, :label, :timestamp_field]

  def new(state, count, timestamp_field) do
    %__MODULE__{
      name: state,
      label: "#{state} (#{count})",
      timestamp_field: timestamp_field
    }
  end
end
