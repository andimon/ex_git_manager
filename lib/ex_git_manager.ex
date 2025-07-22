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
      
      # Interact with an issue (note: deletion not supported by REST API)
      ExGitManager.IssueDeleter.delete_issue("owner", "repo_name", 123)
  """
end
