#!/bin/bash
# setup.sh - Installation script for git-overlap command

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "$THIS_SCRIPT_DIR" && pwd)"

# FILE VARIABLES
ASK_REFRESH=false

install_required_dependencies() {
    # 1. Ensure bash 4+
    if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
    echo "Error: Bash 4 or higher is required. Current version: $BASH_VERSION" >&2
    exit 1
    fi

    # Detect OS type
    LINUX="linux-gnu"
    MACOS="darwin"
    GITBASH="msys"
    WINDOWS="windows_nt"

    # 2. Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        ASK_REFRESH=true
        # Proceed to install jq
        echo "jq not found. Installing jq..."
        if [[ "$OSTYPE" == "$LINUX"* ]]; then
            sudo apt-get update
            sudo apt-get install -y jq
        elif [[ "$OSTYPE" == "$MACOS"* ]]; then
            brew install jq
        elif [[ "$OSTYPE" == "$GITBASH" || "$OSTYPE" == "$WINDOWS" ]]; then
            winget install jqlang.jq
        fi
    fi
}

create_alias() {
    # 1. Add alias to ~/.bashrc to call git-overlap.sh from anywhere
    local line_to_add="alias git-overlap=\"$PROJECT_ROOT_DIR/bin/git-overlap.sh\""
    # Add the alias to ~/.bashrc if it doesn't already exist
    if ! grep -q "alias git-overlap=" ~/.bashrc; then
        echo "$line_to_add" >> ~/.bashrc
        ASK_REFRESH=true
    # Update the alias if it points to a different location
    elif ! grep -qF "$line_to_add" ~/.bashrc; then
        sed -i.bak "/alias git-overlap=/c\\$line_to_add" ~/.bashrc
        ASK_REFRESH=true
    # Otherwise alias already exists and is correct 
    fi

    # 2. Add git alias for easier usage (git overlap ...)  
    git config --global alias.overlap "!sh $PROJECT_ROOT_DIR/bin/git-overlap.sh"
}

# --- Main Execution Block ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    echo "Executing setup for 'git overlap' command..."

    install_required_dependencies
    create_alias

    if [ "$ASK_REFRESH" = true ]; then
        echo "--------------------------------------------------"
        echo -e "\e[33mPLEASE RUN THE FOLLOWING COMMAND TO REFRESH YOUR SHELL:\e[0m"
        echo "source ~/.bashrc"
        echo -e "\e[33mWITHOUT THIS STEP, THE 'git overlap' COMMAND MAY NOT WORK PROPERLY.\e[0m"
        echo "--------------------------------------------------"
    fi
    echo "Installation complete. 'git overlap' is ready to use."
    echo " Execute 'git-overlap --help' to get started."
    echo " eg: 'git overlap --file README.md'"
fi
