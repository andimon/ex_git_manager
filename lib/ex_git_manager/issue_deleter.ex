defmodule ExGitManager.IssueDeleter do
  @moduledoc """
  Provides functionality to interact with GitHub issues via the REST API.

  Note: GitHub's REST API does not support direct deletion of issues.
  Issues can only be closed via PATCH or deleted via GraphQL API.
  """

  require Logger

  @github_api_base_url "https://api.github.com"

  @doc """
  Fetches all issues from a GitHub repository.

  Returns a list of issue numbers for the repository.
  Only fetches open issues by default.

  ## Examples

      ExGitManager.IssueDeleter.fetch_all_issues("owner", "repo_name")
      # => {:ok, [1, 2, 3, 5, 8]}
  """
  def fetch_all_issues(owner, repo_name, opts \\ [])
      when is_binary(owner) and is_binary(repo_name) do
    state = Keyword.get(opts, :state, "open")
    per_page = Keyword.get(opts, :per_page, 100)

    with {:ok, github_token} <- get_github_token() do
      fetch_issues_paginated(owner, repo_name, github_token, state, per_page, 1, [])
    else
      {:error, :github_token_missing} = error -> error
    end
  end

  @doc """
  Deletes all issues from a GitHub repository.

  **WARNING**: This will attempt to delete ALL issues in the repository.
  Since GitHub's REST API doesn't support issue deletion, this will actually
  close all issues instead.

  ## Examples

      # Close all open issues
      ExGitManager.IssueDeleter.delete_all_issues("owner", "repo_name")
      
      # Close all issues (open and closed)
      ExGitManager.IssueDeleter.delete_all_issues("owner", "repo_name", state: "all")
  """
  def delete_all_issues(owner, repo_name, opts \\ [])
      when is_binary(owner) and is_binary(repo_name) do
    Logger.warning("WARNING: This will attempt to delete ALL issues in #{owner}/#{repo_name}")
    Logger.info("Since GitHub REST API doesn't support deletion, issues will be closed instead.")
    Logger.info("Press Enter to continue or Ctrl+C to cancel...")
    IO.read(:line)

    with {:ok, issue_numbers} <- fetch_all_issues(owner, repo_name, opts) do
      if Enum.empty?(issue_numbers) do
        Logger.info("No issues found in #{owner}/#{repo_name}")
        {:ok, []}
      else
        Logger.info("Found #{length(issue_numbers)} issues. Starting deletion process...")

        results =
          issue_numbers
          |> Enum.with_index(1)
          |> Enum.map(fn {issue_number, index} ->
            Logger.info("[#{index}/#{length(issue_numbers)}] Processing issue ##{issue_number}")

            result = close_issue(owner, repo_name, issue_number)

            # Add delay to respect rate limits
            :timer.sleep(1000)

            {issue_number, result}
          end)

        successful = Enum.count(results, fn {_, result} -> result == :ok end)
        failed = length(results) - successful

        Logger.info("Summary:")
        Logger.info("Successfully processed: #{successful}")
        Logger.info("Failed: #{failed}")

        {:ok, results}
      end
    else
      error -> error
    end
  end

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

      Logger.info("Attempting to delete issue ##{issue_number} in #{owner}/#{repo_name}")

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
          Logger.info(
            "Issue ##{issue_number} in '#{owner}/#{repo_name}' deleted successfully (if endpoint existed and responded 204)."
          )

          :ok

        {:ok, %{status: status, body: body}} ->
          error_message =
            case Jason.decode(body) do
              {:ok, %{"message" => message}} -> message
              _ -> "Could not parse error message from response body."
            end

          Logger.error("Failed to delete issue ##{issue_number} in '#{owner}/#{repo_name}'.")
          Logger.error("Status: #{status}, Error: #{error_message}")

          Logger.error(
            "Note: GitHub's REST API does not directly support deleting issues. You might need GraphQL or the GitHub UI."
          )

          {:error, %{status: status, message: error_message}}

        {:error, reason} ->
          Logger.error(
            "Network or Finch error while deleting issue ##{issue_number} in '#{owner}/#{repo_name}': #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :github_token_missing} ->
        Logger.error("Error: GITHUB_TOKEN environment variable is not set.")

        Logger.error(
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

  @doc """
  Closes a GitHub issue (since deletion isn't supported via REST API).
  """
  def close_issue(owner, repo_name, issue_number)
      when is_binary(owner) and is_binary(repo_name) and is_integer(issue_number) do
    with {:ok, github_token} <- get_github_token() do
      headers = build_headers(github_token)
      url = "#{@github_api_base_url}/repos/#{owner}/#{repo_name}/issues/#{issue_number}"

      # Close the issue by updating its state
      body = Jason.encode!(%{"state" => "closed"})
      headers_with_content_type = [{"Content-Type", "application/json"} | headers]

      case Finch.build(:patch, url, headers_with_content_type, body)
           |> Finch.request(ExGitManager.Finch) do
        {:ok, %{status: 200}} ->
          :ok

        {:ok, %{status: status, body: response_body}} ->
          error_message =
            case Jason.decode(response_body) do
              {:ok, %{"message" => message}} -> message
              _ -> "Could not parse error message from response body."
            end

          Logger.error("Failed to close issue ##{issue_number}: #{error_message}")
          {:error, %{status: status, message: error_message}}

        {:error, reason} ->
          Logger.error("Network error closing issue ##{issue_number}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :github_token_missing} = error -> error
    end
  end

  defp fetch_issues_paginated(owner, repo_name, github_token, state, per_page, page, acc) do
    headers = build_headers(github_token)
    url = "#{@github_api_base_url}/repos/#{owner}/#{repo_name}/issues"

    query_params =
      URI.encode_query([
        {"state", state},
        {"per_page", per_page},
        {"page", page}
      ])

    full_url = "#{url}?#{query_params}"

    case Finch.build(:get, full_url, headers) |> Finch.request(ExGitManager.Finch) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, issues} when is_list(issues) ->
            # Filter out pull requests (which are also returned by the issues API)
            issue_numbers =
              issues
              |> Enum.reject(&Map.has_key?(&1, "pull_request"))
              |> Enum.map(& &1["number"])

            new_acc = acc ++ issue_numbers

            # If we got a full page, there might be more
            if length(issues) == per_page do
              fetch_issues_paginated(
                owner,
                repo_name,
                github_token,
                state,
                per_page,
                page + 1,
                new_acc
              )
            else
              {:ok, new_acc}
            end

          {:ok, _} ->
            {:error, "Unexpected response format"}

          {:error, _} ->
            {:error, "Failed to parse JSON response"}
        end

      {:ok, %{status: status, body: body}} ->
        error_message =
          case Jason.decode(body) do
            {:ok, %{"message" => message}} -> message
            _ -> "HTTP #{status}"
          end

        {:error, error_message}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
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
