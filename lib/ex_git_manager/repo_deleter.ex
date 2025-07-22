defmodule ExGitManager.RepoDeleter do
  @moduledoc """
  Provides functionality to delete GitHub repositories via the REST API.

  Requires appropriate GitHub token permissions for repository deletion.
  """

  require Logger

  @github_api_base_url "https://api.github.com"

  @doc """
  Deletes a GitHub repository.

  Requires a GitHub Personal Access Token (PAT) with the 'delete_repo' scope.
  The PAT should be set as an environment variable named GITHUB_TOKEN.

  ## Examples

  1. Set your PAT in the terminal before running:
     (Linux/macOS) export GITHUB_TOKEN="your_personal_access_token"
     (Windows Command Prompt) set GITHUB_TOKEN="your_personal_access_token"
     (Windows PowerShell) $env:GITHUB_TOKEN="your_personal_access_token"

  2. Then, in an `iex -S mix` session from your project's root directory:

     # To delete a single repository:
     ExGitManager.RepoDeleter.delete_repo("your_github_username", "name_of_the_repo_to_delete")

     # To delete multiple repositories:
     repos_to_delete = [
       {"your_github_username", "repo-one"},
       {"your_github_username", "repo-two"},
       {"your_org_name", "org-repo-alpha"}
     ]
     Enum.each(repos_to_delete, fn {owner, repo_name} ->
       ExGitManager.RepoDeleter.delete_repo(owner, repo_name)
       :timer.sleep(1000) # Optional: Add a 1-second delay to avoid rate limits
     end)
  """
  def delete_repo(owner, repo_name) when is_binary(owner) and is_binary(repo_name) do
    with {:ok, github_token} <- get_github_token() do
      headers = build_headers(github_token)

      url = "#{@github_api_base_url}/repos/#{owner}/#{repo_name}"
      Logger.info("Attempting to delete repository: #{owner}/#{repo_name}")

      case Finch.build(:delete, url, headers) |> Finch.request(ExGitManager.Finch) do
        {:ok, %{status: 204}} ->
          Logger.info("Repository '#{owner}/#{repo_name}' deleted successfully.")
          :ok

        {:ok, %{status: status, body: body}} ->
          error_message =
            case Jason.decode(body) do
              {:ok, %{"message" => message}} -> message
              _ -> "Could not parse error message from response body."
            end

          Logger.error("Failed to delete repository '#{owner}/#{repo_name}'.")
          Logger.error("Status: #{status}, Error: #{error_message}")
          {:error, %{status: status, message: error_message}}

        {:error, reason} ->
          Logger.error(
            "Network or Finch error while deleting '#{owner}/#{repo_name}': #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :github_token_missing} ->
        Logger.error("Error: GITHUB_TOKEN environment variable is not set.")

        Logger.error(
          "Please set it with your GitHub Personal Access Token (PAT) that has 'delete_repo' scope."
        )

        {:error, :github_token_missing}
    end
  end

  defp get_github_token do
    case System.get_env("GITHUB_TOKEN") do
      nil -> {:error, :github_token_missing}
      token when is_binary(token) -> {:ok, token}
    end
  end

  defp build_headers(token) do
    [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Bearer #{token}"},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]
  end
end
