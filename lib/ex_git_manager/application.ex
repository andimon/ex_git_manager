defmodule ExGitManager.Application do
  @moduledoc """
  The OTP application for ExGitManager.

  Starts the HTTP client pool for GitHub API interactions.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: ExGitManager.Finch}
    ]

    opts = [strategy: :one_for_one, name: ExGitManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
