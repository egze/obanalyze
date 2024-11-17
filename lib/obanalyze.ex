defmodule Obanalyze do
  @external_resource Path.expand("./README.md")
  @moduledoc File.read!(Path.expand("./README.md"))
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)
             |> String.replace("doc/images", "images")

  @doc """
  Returns the module for the Obanalyze Phoenix.LiveDashboard page.
  """
  def dashboard do
    Obanalyze.Dashboard
  end

  @doc """
  Returns the module for the Obanalyze JS hooks config.
  """
  def hooks do
    Obanalyze.Hooks
  end
end
