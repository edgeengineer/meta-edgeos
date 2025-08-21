# Linear Integration Setup Guide

This repository includes GitHub Actions to automatically sync issues to Linear.

## Setup Instructions

### 1. Get Your Linear API Key

1. Go to Linear Settings → API → Personal API keys
2. Click "Create key"
3. Give it a name like "GitHub Sync"
4. Copy the generated key

### 2. Get Your Linear Team ID

1. Go to Linear Settings → Teams
2. Click on your team
3. Find the team ID in the URL or settings
   - URL format: `linear.app/team-name/...`
   - Or check Team Settings → General → Team ID

### 3. Add Secrets to GitHub Repository

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following secrets:
   - `LINEAR_API_KEY`: Your Linear personal API key
   - `LINEAR_TEAM_ID`: Your Linear team ID

### 4. Choose Your Workflow

We provide two workflow options:

#### Option A: Simple Workflow (Recommended)
- Uses Linear's official GitHub action
- File: `.github/workflows/linear-sync-simple.yml`
- Simpler configuration
- Less customizable

#### Option B: Custom Workflow
- File: `.github/workflows/sync-to-linear.yml`
- More control over sync behavior
- Custom field mapping
- Advanced features

**To use only one workflow**, delete or disable the other file.

### 5. Configure Label Mapping (Optional)

Edit the workflow file to map GitHub labels to Linear labels:

```yaml
label-mapping: |
  bug: Bug
  enhancement: Feature
  documentation: Documentation
  high-priority: High Priority
```

### 6. Test the Integration

1. Create a test issue in GitHub
2. Check Linear to see if it appears
3. The GitHub issue should get a comment with the Linear link

## Features

### What Gets Synced

- **Issue creation**: New GitHub issues create Linear issues
- **Issue updates**: Title and description changes sync
- **Issue state**: Closing/reopening GitHub issues updates Linear
- **Comments**: GitHub comments can be synced as Linear comments
- **Labels**: GitHub labels can map to Linear labels

### What Doesn't Sync

- Linear → GitHub (one-way sync only)
- Issue assignments (requires user mapping)
- Milestones/Projects → Linear cycles
- Pull requests

## Troubleshooting

### Issues Not Syncing

1. Check the Actions tab for workflow runs
2. Look for error messages in the workflow logs
3. Verify secrets are correctly set
4. Ensure Linear API key has necessary permissions

### Duplicate Issues

The workflow checks for existing Linear issues by looking for the GitHub URL in the description. If duplicates appear:
1. Check if the GitHub URL is properly included
2. Manually link or delete duplicates
3. Review workflow logs for errors

### Label Mapping Not Working

1. Ensure Linear labels exist with exact names
2. Check label mapping configuration in workflow
3. Linear label names are case-sensitive

## Advanced Configuration

### Custom Field Mapping

To map GitHub issue fields to Linear custom fields, modify the GraphQL mutation in the custom workflow:

```javascript
const variables = {
  input: {
    teamId: linearTeamId,
    title: issue.title,
    description: issue.body,
    // Add custom fields here
    customFields: {
      "field_id": "value"
    }
  }
};
```

### Priority Mapping

The custom workflow maps priorities based on labels:
- `critical` or `urgent` → P1
- `high-priority` → P2
- `medium-priority` → P3
- `low-priority` → P4

### State Mapping

By default:
- Open GitHub issues → Linear "Todo" or "In Progress"
- Closed GitHub issues → Linear "Done" or "Completed"

Customize this in the `getStateId()` function.

## Security Notes

- Never commit API keys directly to the repository
- Use GitHub Secrets for all sensitive information
- Limit API key permissions in Linear to minimum required
- Consider using a service account instead of personal API key

## Support

For issues with:
- **GitHub Actions**: Check GitHub Actions documentation
- **Linear API**: Refer to [Linear API docs](https://developers.linear.app/)
- **This integration**: Open an issue in this repository