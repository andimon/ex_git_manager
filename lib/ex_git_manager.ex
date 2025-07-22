defmodule ExGitManager do
  @moduledoc """
  ExGitManager provides utilities for managing GitHub repositories and issues.

  This library offers functionality to delete GitHub repositories and interact
  with issues through the GitHub REST API.

  ## Configuration

  Set your GitHub Personal Access Token as an environment variable:

      export GITHUB_TOKEN="your_personal_access_token"

  ## Usage

      # Delete a repository
      ExGitManager.RepoDeleter.delete_repo("owner", "repo_name")
      
      # Close an issue (REST API - doesn't truly delete)
      ExGitManager.IssueDeleter.delete_issue("owner", "repo_name", 123)
      
      # Close all issues in a repository (REST API)
      ExGitManager.IssueDeleter.delete_all_issues("owner", "repo_name")
      
      # PERMANENTLY delete an issue (GraphQL API)
      ExGitManager.IssueDeleter.delete_issue_graphql("I_kwDOIV8V6M5WM_mv")
      
      # PERMANENTLY delete all issues (GraphQL API) 
      ExGitManager.IssueDeleter.delete_all_issues_graphql("owner", "repo_name")
      
      # Fetch all issues from a repository (REST API)
      ExGitManager.IssueDeleter.fetch_all_issues("owner", "repo_name")
      
      # Fetch all issues with GraphQL node IDs
      ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo_name")
  """
end
