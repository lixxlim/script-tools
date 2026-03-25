# GitHub workflow runner with interactive selection
gh_workflow_run() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh CLI is not installed."
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed."
        return 1
    fi

    local selected
    selected=$(gh workflow list --all --json name,id,state --jq '.[] | "\(.name)\t\(.state)\t\(.id)"' | \
        fzf --header "Select a workflow to run (Tab to select, Enter to run)" \
            --preview 'gh workflow view {3}' \
            --delimiter '\t' \
            --with-nth 1,2) || return

    if [[ -n "$selected" ]]; then
        local workflow_id
        workflow_id=$(echo "$selected" | cut -f3)
        local workflow_name
        workflow_name=$(echo "$selected" | cut -f1)
        
        echo "Running workflow: $workflow_name (ID: $workflow_id)"
        gh workflow run "$workflow_id"
    fi
}

gh_workflow_run "$@"
unfunction gh_workflow_run 2>/dev/null
