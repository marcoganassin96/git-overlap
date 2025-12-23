Windows-specific notes for Git Conflicts Predictor

Quick start (Windows, using Git Bash):

1. Install Git for Windows (https://git-scm.com/download/win) to get Git Bash and bash available.
2. Ensure `jq` and `curl` are installed and available in PATH (e.g., via Scoop or Chocolatey):
   - Scoop: `scoop install jq curl`
   - Chocolatey: `choco install jq curl`
3. After installing the package (zip or installer), open Git Bash and run:

   conflicts_relevator --file src/main.py

Shim behavior:
- conflicts_relevator.cmd is a small Windows shim that locates bash and forwards arguments to the bundled bin/conflicts_relevator.sh script so the POSIX shell implementation runs inside Git Bash.
