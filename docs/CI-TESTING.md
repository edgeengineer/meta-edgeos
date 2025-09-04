# EdgeOS CI/CD Testing Documentation

## Overview

EdgeOS uses GitHub Actions for continuous integration to validate pull requests and ensure code quality.

## CI Pipeline Stages

### 1. Quick Validation (5 minutes)
- Repository structure validation
- Recipe syntax checking  
- Bootstrap script validation
- Runs on every PR and push

### 2. Incremental Tests (45 minutes)
- Layer compatibility testing
- Recipe parsing (syntax validation)
- Critical recipe compilation
- Dependency graph generation
- Configuration validation
- Runs on every PR and push

### 3. Full Build (2-6 hours)
- Complete EdgeOS image build
- Artifact generation and upload
- Runs only on:
  - Merges to main branch
  - PRs with `full-build` label

## Running Tests Locally

### Quick Validation
```bash
./scripts/validate-pr.sh
```

### Parse Test
```bash
source sources/poky/oe-init-build-env build
bitbake -p
```

### Build Specific Recipe
```bash
source sources/poky/oe-init-build-env build
bitbake -c compile edgeos-identity
bitbake -c compile usb-gadget
```

### Full Build
```bash
./bootstrap.sh
source sources/poky/oe-init-build-env build
bitbake edgeos-image
```

## CI Configuration

### Triggering Full Builds

To trigger a full build on a PR, add the `full-build` label:
```bash
gh pr edit <pr-number> --add-label full-build
```

### Caching Strategy

The CI uses two-level caching:
1. **Downloads cache**: Shared source downloads
2. **Sstate cache**: Shared state for faster rebuilds

### Required Secrets

The following secrets must be configured in GitHub:
- `LINEAR_API_KEY`: For issue syncing
- `LINEAR_TEAM_ID`: For issue syncing

## Troubleshooting

### Recipe Parse Failures
```bash
# Get detailed error
bitbake -p -v
```

### Layer Compatibility Issues
```bash
bitbake-layers check-layer-compatibility
```

### Dependency Issues
```bash
# Generate dependency graph
bitbake -g edgeos-image
# View with graphviz
dot -Tpng task-depends.dot -o depends.png
```

## Best Practices

1. **Before Creating PR**:
   - Run `./scripts/validate-pr.sh`
   - Test recipe parsing with `bitbake -p`
   - Check for uncommitted files

2. **Writing Recipes**:
   - Always include LICENSE and LIC_FILES_CHKSUM
   - Add SUMMARY or DESCRIPTION
   - Use 4 spaces, not tabs
   - No hardcoded paths

3. **Committing**:
   - No large binary files (>1MB)
   - No secrets or credentials
   - Clear commit messages

## CI Status Badge

Add to your README:
```markdown
![CI Status](https://github.com/edgeengineer/meta-edgeos/actions/workflows/test.yml/badge.svg)
```

## Performance Tips

- PR validation completes in ~45 minutes
- Full builds can take 2-6 hours
- Use `[skip ci]` in commit message to skip CI
- Incremental changes rebuild faster due to sstate cache

## Getting Help

- Check workflow logs in Actions tab
- Review failed job details
- Create issue with `ci-problem` label for CI issues