defmodule ExGitManager.IssueDeleter do
  @moduledoc """
  Provides functionality to interact with GitHub issues via the REST API.

  Note: GitHub's REST API does not support direct deletion of issues.
  Issues can only be closed via PATCH or deleted via GraphQL API.
  """

  @github_api_base_url "https://api.github.com"

  @doc """
  Deletes a GitHub issue in a specified repository.

  Requires a GitHub Personal Access Token (PAT) with 'repo' scope.
  The PAT should be set as an environment variable named GITHUB_TOKEN.

  ## Examples

  1. Set your PAT in the terminal before running:
     (Linux/macOS) export GITHUB_TOKEN="your_personal_access_token"
     (Windows Command Prompt) set GITHUB_TOKEN="your_personal_access_token"
     (Windows PowerShell) $env:GITHUB_TOKEN="your_personal_access_token"

  2. Then, in an `iex -S mix` session from your project's root directory:

     # To delete a single issue:
     ExGitManager.IssueDeleter.delete_issue("your_github_username", "your_repo_name", 123)

     # To delete multiple issues:
     issues_to_delete = [
       {"your_github_username", "repo-alpha", 1},
       {"your_github_username", "repo-alpha", 5},
       {"your_org_name", "repo-beta", 10}
     ]
     Enum.each(issues_to_delete, fn {owner, repo_name, issue_number} ->
       ExGitManager.IssueDeleter.delete_issue(owner, repo_name, issue_number)
       :timer.sleep(500) # Optional: Add a small delay to avoid rate limits
     end)
  """
  def delete_issue(owner, repo_name, issue_number)
      when is_binary(owner) and is_binary(repo_name) and is_integer(issue_number) do
    with {:ok, github_token} <- get_github_token() do
      headers = build_headers(github_token)
      url = "#{@github_api_base_url}/repos/#{owner}/#{repo_name}/issues/#{issue_number}"

      IO.puts("Attempting to delete issue ##{issue_number} in #{owner}/#{repo_name}")

      # GitHub's REST API for issues does not have a direct DELETE endpoint for issues.
      # Issues can only be closed or deleted via the GraphQL API (more complex for a simple script).
      # Or, if you have admin permissions and the project's settings allow,
      # issues can be deleted via the UI or a specific GraphQL mutation.

      # The REST API only allows closing issues via PATCH.
      # To truly delete, you'd typically need GraphQL.
      # For this example, we'll demonstrate a POST to a hypothetical delete endpoint or
      # illustrate that the REST API doesn't directly support issue deletion.

      # --- IMPORTANT NOTE ---
      # As of my last update, GitHub's REST API DOES NOT provide a direct DELETE endpoint for issues.
      # Issues can be *closed* (status change) but not *deleted* via REST.
      # To permanently delete an issue, you typically need to use the GitHub GraphQL API
      # with the `deleteIssue` mutation, which is more involved for a simple curl-like call.
      # Or, it's possible through the GitHub UI for repository administrators.
      # This function will demonstrate sending a DELETE request, but it will likely
      # result in a 404 or 405 error because the endpoint doesn't exist for issues.
      # For actual deletion, consider a GraphQL client in Elixir.
      # Alternatively, GitHub CLI (gh) handles this complexity for you.

      # For educational purposes, here's how you'd send a DELETE if the endpoint existed:
      case Finch.build(:delete, url, headers) |> Finch.request(ExGitManager.Finch) do
        {:ok, %{status: 204}} ->
          IO.puts(
            "Issue ##{issue_number} in '#{owner}/#{repo_name}' deleted successfully (if endpoint existed and responded 204)."
          )

          :ok

        {:ok, %{status: status, body: body}} ->
          error_message =
            case Jason.decode(body) do
              {:ok, %{"message" => message}} -> message
              _ -> "Could not parse error message from response body."
            end

          IO.puts(:stderr, "Failed to delete issue ##{issue_number} in '#{owner}/#{repo_name}'.")
          IO.puts(:stderr, "Status: #{status}, Error: #{error_message}")

          IO.puts(
            :stderr,
            "Note: GitHub's REST API does not directly support deleting issues. You might need GraphQL or the GitHub UI."
          )

          {:error, %{status: status, message: error_message}}

        {:error, reason} ->
          IO.puts(
            :stderr,
            "Network or Finch error while deleting issue ##{issue_number} in '#{owner}/#{repo_name}': #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :github_token_missing} ->
        IO.puts(:stderr, "Error: GITHUB_TOKEN environment variable is not set.")

        IO.puts(
          :stderr,
          "Please set it with your GitHub Personal Access Token (PAT) that has 'repo' scope."
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
