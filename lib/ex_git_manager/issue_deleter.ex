defmodule ExGitManager.IssueDeleter do
  @moduledoc """
  Provides functionality to interact with GitHub issues via REST and GraphQL APIs.

  Note: GitHub's REST API does not support direct deletion of issues.
  Issues can be closed via PATCH (REST) or truly deleted via GraphQL API.
  """

  require Logger

  @github_api_base_url "https://api.github.com"
  @github_graphql_url "https://api.github.com/graphql"

  @doc """
  Fetches all issues from a GitHub repository using GraphQL API.

  Returns a list of maps with issue numbers and node IDs for GraphQL operations.
  Only fetches open issues by default.

  ## Examples

      ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo_name")
      # => {:ok, [%{number: 1, node_id: "I_kwD..."}, %{number: 2, node_id: "I_kwD..."}]}
  """
  def fetch_all_issues_graphql(owner, repo_name, opts \\ [])
      when is_binary(owner) and is_binary(repo_name) do
    state = Keyword.get(opts, :state, "OPEN")
    first = Keyword.get(opts, :first, 100)

    with {:ok, github_token} <- get_github_token() do
      fetch_issues_graphql_paginated(owner, repo_name, github_token, state, first, nil, [])
    else
      {:error, :github_token_missing} = error -> error
    end
  end

  @doc """
  Fetches all issues from a GitHub repository using REST API.

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
  Debug function to test GraphQL connectivity and see what issues exist.
  
  ## Examples
  
      ExGitManager.IssueDeleter.debug_issues("owner", "repo_name")
  """
  def debug_issues(owner, repo_name) when is_binary(owner) and is_binary(repo_name) do
    Logger.info("Checking for issues in #{owner}/#{repo_name}...")
    
    Logger.info("Fetching OPEN issues via GraphQL:")
    case fetch_all_issues_graphql(owner, repo_name, state: "OPEN") do
      {:ok, issues} -> Logger.info("Found #{length(issues)} OPEN issues: #{inspect(issues)}")
      {:error, error} -> Logger.error("Error fetching OPEN issues: #{inspect(error)}")
    end
    
    Logger.info("Fetching CLOSED issues via GraphQL:")
    case fetch_all_issues_graphql(owner, repo_name, state: "CLOSED") do
      {:ok, issues} -> Logger.info("Found #{length(issues)} CLOSED issues: #{inspect(issues)}")
      {:error, error} -> Logger.error("Error fetching CLOSED issues: #{inspect(error)}")
    end
    
    Logger.info("Fetching ALL issues via GraphQL:")
    case fetch_all_issues_graphql(owner, repo_name, state: "ALL") do
      {:ok, issues} -> Logger.info("Found #{length(issues)} ALL issues: #{inspect(issues)}")
      {:error, error} -> Logger.error("Error fetching ALL issues: #{inspect(error)}")
    end
    
    Logger.info("Fetching issues via REST API (for comparison):")
    case fetch_all_issues(owner, repo_name, state: "all") do
      {:ok, issues} -> Logger.info("Found #{length(issues)} issues via REST: #{inspect(issues)}")
      {:error, error} -> Logger.error("Error fetching via REST: #{inspect(error)}")
    end
    
    :ok
  end

  @doc """
  Truly deletes an issue using GitHub's GraphQL API.

  ## Examples

      ExGitManager.IssueDeleter.delete_issue_graphql("I_kwDOIV8V6M5WM_mv")
  """
  def delete_issue_graphql(issue_node_id) when is_binary(issue_node_id) do
    with {:ok, github_token} <- get_github_token() do
      mutation = """
      mutation($issueId: ID!) {
        deleteIssue(input: {
          issueId: $issueId
        }) {
          repository {
            id
          }
        }
      }
      """

      headers = build_graphql_headers(github_token)
      body = Jason.encode!(%{
        query: mutation,
        variables: %{issueId: issue_node_id}
      })

      case Finch.build(:post, @github_graphql_url, headers, body)
           |> Finch.request(ExGitManager.Finch) do
        {:ok, %{status: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, %{"data" => %{"deleteIssue" => _}}} ->
              :ok

            {:ok, %{"errors" => errors}} ->
              error_msg = errors |> Enum.map(& &1["message"]) |> Enum.join(", ")
              Logger.error("GraphQL error deleting issue: #{error_msg}")
              {:error, error_msg}

            {:error, _} ->
              {:error, "Failed to parse GraphQL response"}
          end

        {:ok, %{status: status, body: response_body}} ->
          Logger.error("GraphQL request failed with status #{status}: #{response_body}")
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          Logger.error("Network error in GraphQL request: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :github_token_missing} = error -> error
    end
  end

  @doc """
  Deletes all issues from a GitHub repository using GraphQL API for true deletion.

  **WARNING**: This will PERMANENTLY DELETE ALL issues in the repository.
  This operation cannot be undone!

  ## Examples

      # Delete all open issues (PERMANENT)
      ExGitManager.IssueDeleter.delete_all_issues_graphql("owner", "repo_name")
      
      # Delete all issues (PERMANENT)
      ExGitManager.IssueDeleter.delete_all_issues_graphql("owner", "repo_name", state: "all")
      
      # Debug what issues exist
      ExGitManager.IssueDeleter.debug_issues("owner", "repo_name")
  """
  def delete_all_issues_graphql(owner, repo_name, opts \\ [])
      when is_binary(owner) and is_binary(repo_name) do
    Logger.warning("DANGER: This will PERMANENTLY DELETE ALL issues in #{owner}/#{repo_name}")
    Logger.warning("This operation CANNOT BE UNDONE!")
    Logger.info("Type 'DELETE' and press Enter to continue, or Ctrl+C to cancel...")

    case IO.read(:line) |> String.trim() do
      "DELETE" ->
        proceed_with_graphql_deletion(owner, repo_name, opts)

      _ ->
        Logger.info("Operation cancelled.")
        {:ok, :cancelled}
    end
  end

  @doc """
  Deletes all issues from a GitHub repository (closes via REST API).

  **WARNING**: This will attempt to close ALL issues in the repository.
  Uses REST API which can only close issues, not delete them.

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

  defp proceed_with_graphql_deletion(owner, repo_name, opts) do
    state_param =
      case Keyword.get(opts, :state, "open") do
        "all" -> "ALL"
        "closed" -> "CLOSED"
        _ -> "OPEN"
      end

    with {:ok, issues} <- fetch_all_issues_graphql(owner, repo_name, state: state_param) do
      if Enum.empty?(issues) do
        Logger.info("No issues found in #{owner}/#{repo_name}")
        {:ok, []}
      else
        Logger.info("Found #{length(issues)} issues. Starting PERMANENT deletion process...")

        results =
          issues
          |> Enum.with_index(1)
          |> Enum.map(fn {%{number: issue_number, node_id: node_id}, index} ->
            Logger.info(
              "[#{index}/#{length(issues)}] Permanently deleting issue ##{issue_number}"
            )

            result = delete_issue_graphql(node_id)

            # Add delay to respect rate limits
            :timer.sleep(1000)

            {issue_number, result}
          end)

        successful = Enum.count(results, fn {_, result} -> result == :ok end)
        failed = length(results) - successful

        Logger.info("Summary:")
        Logger.info("Successfully deleted: #{successful}")
        Logger.info("Failed: #{failed}")

        {:ok, results}
      end
    else
      error -> error
    end
  end

  defp fetch_issues_graphql_paginated(owner, repo_name, github_token, state, first, cursor, acc) do
    {query, variables} = build_issues_query(owner, repo_name, state, first, cursor)
    
    request_body = %{
      query: query,
      variables: variables
    }

    headers = build_graphql_headers(github_token)
    body = Jason.encode!(request_body)

    case Finch.build(:post, @github_graphql_url, headers, body)
         |> Finch.request(ExGitManager.Finch) do
      {:ok, %{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"data" => %{"repository" => %{"issues" => issues_data}}}} ->
            issues =
              issues_data["nodes"]
              |> Enum.map(fn issue ->
                %{number: issue["number"], node_id: issue["id"]}
              end)

            new_acc = acc ++ issues

            # Check if there are more pages
            if issues_data["pageInfo"]["hasNextPage"] do
              next_cursor = issues_data["pageInfo"]["endCursor"]

              fetch_issues_graphql_paginated(
                owner,
                repo_name,
                github_token,
                state,
                first,
                next_cursor,
                new_acc
              )
            else
              {:ok, new_acc}
            end

          {:ok, %{"errors" => errors}} ->
            error_msg = errors |> Enum.map(& &1["message"]) |> Enum.join(", ")
            {:error, "GraphQL errors: #{error_msg}"}

          {:error, _} ->
            {:error, "Failed to parse GraphQL response"}
        end

      {:ok, %{status: status, body: response_body}} ->
        {:error, "GraphQL request failed: HTTP #{status} - #{response_body}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp build_issues_query(owner, repo_name, state, first, cursor) do
    query = """
    query($owner: String!, $repo: String!, $state: [IssueState!], $first: Int!, $after: String) {
      repository(owner: $owner, name: $repo) {
        issues(states: $state, first: $first, after: $after) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            number
            id
          }
        }
      }
    }
    """
    
    # Convert state string to proper GraphQL enum format
    state_list = case state do
      "OPEN" -> ["OPEN"]
      "CLOSED" -> ["CLOSED"]
      "ALL" -> ["OPEN", "CLOSED"]
      _ -> ["OPEN"]
    end
    
    variables = %{
      owner: owner,
      repo: repo_name,
      state: state_list,
      first: first,
      after: cursor
    }
    
    {query, variables}
  end

  defp build_graphql_headers(token) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"},
      {"Accept", "application/vnd.github+json"}
    ]
  end

  defp build_headers(token) do
    [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Bearer #{token}"},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]
  end
end
