# ExGitManager

A powerful Elixir library for managing GitHub repositories and issues through REST and GraphQL APIs.

## Features

- **Repository Management**: Delete GitHub repositories
- **Issue Management**: Close or permanently delete GitHub issues
- **Dual API Support**: REST API (for closing) and GraphQL API (for true deletion)
- **Bulk Operations**: Process multiple issues or repositories at once
- **Safety Features**: Confirmation prompts and detailed logging

## Configuration

Set your GitHub Personal Access Token as an environment variable:

```bash
export GITHUB_TOKEN="your_personal_access_token_here"
```

### Required Token Permissions

- **For repository deletion**: `delete_repo` scope
- **For issue operations**: `repo` scope (includes issues access)

## Usage

### Repository Operations

```elixir
# Delete a repository
ExGitManager.RepoDeleter.delete_repo("owner", "repo_name")
```

### Issue Operations

ExGitManager provides two approaches for issue management:

#### 1. REST API (Closes Issues)
```elixir
# Close a single issue (reversible)
ExGitManager.IssueDeleter.delete_issue("owner", "repo_name", 123)

# Close all open issues (reversible)
ExGitManager.IssueDeleter.delete_all_issues("owner", "repo_name")

# Close all issues (open and closed - makes them all closed)
ExGitManager.IssueDeleter.delete_all_issues("owner", "repo_name", state: "all")

# Fetch all issues (REST API)
ExGitManager.IssueDeleter.fetch_all_issues("owner", "repo_name")
```

#### 2. GraphQL API (Permanent Deletion) ⚠️ DANGER

```elixir
# PERMANENTLY delete a single issue (cannot be undone!)
ExGitManager.IssueDeleter.delete_issue_graphql("I_kwDOIV8V6M5WM_mv")

# PERMANENTLY delete all open issues (cannot be undone!)
ExGitManager.IssueDeleter.delete_all_issues_graphql("owner", "repo_name")

# PERMANENTLY delete ALL issues including closed ones (cannot be undone!)
ExGitManager.IssueDeleter.delete_all_issues_graphql("owner", "repo_name", state: "all")

# Fetch issues with GraphQL node IDs (needed for GraphQL operations)
ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo_name", state: "ALL")
```

## Delete Issues - Step by Step Guide

### Method 1: Close Issues (Safe, Reversible)

1. **Set your GitHub token**:
   ```bash
   export GITHUB_TOKEN="ghp_your_token_here"
   ```

2. **Start an IEx session**:
   ```bash
   cd your_project_directory
   iex -S mix
   ```

3. **Close issues**:
   ```elixir
   # Close all open issues
   ExGitManager.IssueDeleter.delete_all_issues("your_username", "your_repo")
   
   # Or close a specific issue
   ExGitManager.IssueDeleter.delete_issue("your_username", "your_repo", 42)
   ```

### Method 2: Permanently Delete Issues (Dangerous!)

⚠️ **WARNING**: This operation cannot be undone! Issues will be permanently deleted from GitHub.

1. **Set your GitHub token** (same as above)

2. **Start an IEx session** (same as above)

3. **Permanently delete issues**:
   ```elixir
   # This will prompt for confirmation
   ExGitManager.IssueDeleter.delete_all_issues_graphql("your_username", "your_repo")
   
   # Delete including closed issues
   ExGitManager.IssueDeleter.delete_all_issues_graphql("your_username", "your_repo", state: "all")
   ```

4. **Type "DELETE" when prompted** to confirm permanent deletion

### Checking What Issues Exist

Before deleting, you can inspect what issues exist:

```elixir
# Debug function - shows all issue states
ExGitManager.IssueDeleter.debug_issues("owner", "repo_name")

# Fetch specific states
ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo", state: "OPEN")
ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo", state: "CLOSED") 
ExGitManager.IssueDeleter.fetch_all_issues_graphql("owner", "repo", state: "ALL")
```

## State Parameters

| Parameter | REST API | GraphQL API | Description |
|-----------|----------|-------------|-------------|
| `"open"` | ✅ | `"OPEN"` | Open issues only |
| `"closed"` | ✅ | `"CLOSED"` | Closed issues only |
| `"all"` | ✅ | `"ALL"` | Both open and closed |

## API Comparison

| Operation | REST API | GraphQL API | Reversible | Notes |
|-----------|----------|-------------|------------|-------|
| Single issue | Closes issue | **Deletes issue** | ✅ / ❌ | REST: reopenable, GraphQL: permanent |
| All issues | Closes all | **Deletes all** | ✅ / ❌ | GraphQL requires "DELETE" confirmation |
| Speed | Moderate | Moderate | - | Both have rate limiting |
| Permissions | `repo` scope | `repo` scope | - | Same token permissions |

## Safety Features

- **Confirmation prompts** for destructive operations
- **Rate limiting** (1-second delays between operations)
- **Progress tracking** with `[current/total]` indicators  
- **Detailed logging** of all operations
- **Error handling** with descriptive messages
- **Summary reports** showing success/failure counts

## Troubleshooting

### "No issues found" but issues exist

- Check if you're looking for the right state: `state: "ALL"` includes both open and closed
- Verify repository name and owner are correct
- Ensure your token has `repo` scope permissions

### Rate limiting errors

The library includes automatic 1-second delays, but for very large repositories you may need to:
- Use smaller batch sizes
- Take breaks between large operations
- Check your GitHub API rate limits

### Permission errors

Ensure your GitHub token has the required scopes:
- `repo` - for issue operations
- `delete_repo` - for repository deletion

## Examples

```elixir
# Complete workflow example
iex> ExGitManager.IssueDeleter.debug_issues("myuser", "myrepo")
# ... shows what issues exist ...

iex> ExGitManager.IssueDeleter.delete_all_issues_graphql("myuser", "myrepo", state: "all")
# WARNING: This will PERMANENTLY DELETE ALL issues in myuser/myrepo
# This operation CANNOT BE UNDONE!
# Type 'DELETE' and press Enter to continue, or Ctrl+C to cancel...
DELETE
# Found 5 issues. Starting PERMANENT deletion process...
# [1/5] Permanently deleting issue #1
# [2/5] Permanently deleting issue #3
# ...
# Summary:
# Successfully deleted: 5
# Failed: 0
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

⚠️ **Use at your own risk!** This tool can permanently delete GitHub issues and repositories. Always test with non-important data first. The authors are not responsible for any data loss.