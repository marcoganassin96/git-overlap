# Git Conflicts Predictor

A powerful multi-provider tool that helps developers identify files overlaps and potential merge conflicts before they occur by analyzing which open Pull Requests (PRs) or Merge Requests (MRs) are modifying the same files you're working on.


## 📖 Usage

### 📊 Example
```bash
$ ./bin/conflicts_relevator.sh --file src/main.py,README.md,src/foo.py

Debug: Parsed repository full name from REMOTE_URL: https://github.com/marcoganassin96/git-conflicts-predictor
🔑 Searching GitHub for PRs modifying 2 file(s) via gh CLI...
Debug: Analyzing 15 open PR(s) in the repository...

Processing PR 15 of 15: #132 (docs/readme)...

--- Results ---
File: **src/main.py** is modified in PRs:
PR #121: feature/user-authentication
PR #123: bugfix/login-validation

File: **README.md** is modified in PRs:
PR #132: docs/readme
```

### Basic Usage
```bash
# Analyze a single file
./bin/conflicts_relevator.sh --file src/main.py

# Analyze multiple files
./bin/conflicts_relevator.sh --file src/main.py --file README.md

# Analyze comma-separated files
./bin/conflicts_relevator.sh --file "src/main.py,README.md,package.json"
```

### Advanced Usage
```bash
./bin/conflicts_relevator.sh --file "README.md,sparkling_water/ai_engine/ai.py" --url "https://github.com/marcoganassin96/git-conflicts-predictor-tester-github.git" --method api --limit 50
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--file <path>` | File path to analyze (required, can be used multiple times) | `--file src/main.py` |
| `--url <url>` | Git remote URL (optional, auto-detected if not provided) | `--url https://github.com/user/repo.git` |
| `--method <gh\|api>` | Method to use for querying provider: `gh` (GitHub CLI) or `api` (REST via curl). If omitted the script auto-detects the best available method. | `--method api` |
| `--limit <number>` | Maximum number of open PRs to analyze (defaults to 200). Useful to cap work when repositories have many open PRs. | `--limit 100` |


### Environment Variables
| Variable | Description | Example |
|----------|-------------|---------
| `GITHUB_TOKEN` | GitHub Personal Access Token for API authentication (required if using API method) | `export GITHUB_TOKEN='your_token_here'` |
| `BITBUCKET_TOKEN` | Bitbucket Token for API authentication (required for Bitbucket API method) | `export BITBUCKET_TOKEN='your_token_here'` |
| `DEBUG` | Enable logging debug messages when set to `1` | `export DEBUG=1` |


## 🚀 Features

- **Multi-Provider Support**: Currently works with GitHub and Bitbucket. GitLab support is planned.
- **Automatic Provider Detection**: Automatically detects the Git hosting provider from remote URLs
- **Flexible Input**: Support for overlap detection with multiple files and custom remote repo. In future, files you're working on will be used by default.
- **Multiple Access Methods**: Uses CLI tools (like `gh` for GitHub) when available for better performance, otherwise falls back to REST API.
- **Comprehensive Output**: Provides detailed output of overlapping files and associated PRs/MRs.


## 🎯 Use Cases

### 1. Team Coordination
Help teams identify potential conflicts in their work in early stages, so they can coordinate planning of their actual work!

### 2. Avoid Redundant Work
Find out if someone else is already working on the same files/features you're thinking to add/modify, before actually starting the work!

### 3. Pre-Merge Conflict Detection
Check for potential conflicts before creating a PR


## 📋 Supported Providers

| Provider | CLI Tool | API Method | Authentication | Working Status |
|----------|----------|------------|----------------|----------------|
| **GitHub** | `gh` (recommended) | REST API | `GITHUB_TOKEN` | ✅ Fully Supported |
| **Bitbucket** | N/A | REST API | `BITBUCKET_TOKEN` | ✅ Added (API)
| **GitLab** | `glab` (recommended) | REST API | `GITLAB_TOKEN` | 🛠 Work in Progress |


## 🚀 Release Planning
- Bitbucket provider: added (API-based implementation)
- Implementation for GitLab provider
- Auto-detection of files in current working branch as default --file input
- Publish as installable package (e.g., via homebrew)


## 🛠 Installation & Dependencies

### Required Dependencies
- `jq` - JSON processor (required for all providers)
- `curl` - HTTP client (required for API methods)

### Optional CLI Tools (Recommended)
- `gh` - GitHub CLI (for better GitHub performance)
- `glab` - GitLab CLI (for better GitLab performance)

### Install Dependencies

**Linux (Debian/Ubuntu):**
```bash
sudo apt install jq curl
# Optional: Install CLI tools
sudo apt install gh
curl -s https://gitlab.com/gitlab-org/cli/-/releases/permalink/latest/downloads/glab_linux_amd64.deb -o glab.deb && sudo dpkg -i glab.deb
```

**macOS (Homebrew):**
```bash
brew install jq curl gh glab
```

**Windows:**
```bash
winget install jqlang.jq
winget install GitHub.cli
winget install GitLab.GitLabCLI
```

## 🔐 Authentication Setup

### GitHub
```bash
# Method 1: Using GitHub CLI (recommended)
gh auth login

# Method 2: Using Personal Access Token
export GITHUB_TOKEN='your_github_token_here'
```

### Bitbucket
```bash
export BITBUCKET_USERNAME='your_username'
export BITBUCKET_TOKEN='your_app_password'
```

### GitLab
```bash
# Method 1: Using GitLab CLI (recommended)
glab auth login

# Method 2: Using Personal Access Token
export GITLAB_TOKEN='your_gitlab_token_here'
```

## Unit Tests
To run unit tests, execute the following command from the project root:
```bash
./tests/run_tests.sh
```

## 🔧 Troubleshooting

### Common Issues

**Authentication Errors:**
- Ensure tokens are set correctly in environment variables
- Verify token permissions (repo access for GitHub, read_api for GitLab)
- For Bitbucket, ensure both username and app password are set

**Missing Dependencies:**
- Install `jq` and `curl` as they are required for all providers
- Install CLI tools (`gh`, `glab`) for better performance

**API Rate Limits:**
- GitHub: 5,000 requests per hour with token
- Bitbucket: 1,000 requests per hour
- GitLab: 2,000 requests per minute

## 📄 License

This project is open source. Feel free to use, modify, and distribute.
