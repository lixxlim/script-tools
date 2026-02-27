# AGENTS.md - Project Context

This document provides contextual information about the `script-tools` project.

## Project Overview

The `script-tools` repository is a collection of utility shell scripts developed for both Bash and Zsh environments. These scripts aim to automate common tasks, primarily focusing on file encoding management and providing an interactive command execution menu. The project is structured with separate directories (`bash/` and `zsh/`) to maintain shell-specific implementations of similar functionalities.

**Main Technologies:**
*   **Bash/Zsh:** Core scripting environments.
*   **nkf:** Used for character encoding detection and conversion.
*   **fzf:** Used for interactive menu selection in the `cmd` script.

## Building and Running

This project does not involve a traditional "build" step as it consists of shell scripts (functions). The primary method of "running" these tools is by sourcing the scripts into your shell environment, which makes the defined functions available for execution.

To make the scripts available in your shell:

1.  **Clone the repository**:
    ```bash
    git clone <repository-url> /path/to/your/script-tools
    ```
2.  **Configure your shell**: Add the following snippets to your shell's configuration file (e.g., `~/.bashrc`, `~/.bash_profile` for Bash, or `~/.zshrc` for Zsh), adjusting `SCRIPT_TOOLS_PATH` to the actual path where you cloned the repository.

    ### Bash Scripts Loading (.bashrc or .bash_profile)
    ```bash
    # Set the actual path to your script-tools repository.
    export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

    for script in "$SCRIPT_TOOLS_PATH"/bash/*.sh; do
      if [ -f "$script" ]; then
        source "$script"
      fi
    done
    ```

    ### Zsh Scripts Loading (.zshrc)
    ```zsh
    # Set the actual path to your script-tools repository.
    export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

    for script in "$SCRIPT_TOOLS_PATH"/zsh/*.zsh; do
      if [ -f "$script" ]; then
        source "$script"
      fi
    done
    ```

After sourcing, you can run the functions directly (e.g., `check-encode`, `cmd`, `convert_encode_to_utf8`).

## Development Conventions

*   **Script Naming:** Scripts within the `bash/` directory typically end with `.sh`, and those in `zsh/` end with `.zsh`. Function names generally correspond to the script name, often using hyphens in the script name and underscores in the function name for multi-word commands (e.g., `convert-encode-to-utf8.sh` defines `convert_encode_to_utf8`).
*   **Shell Compatibility:** Efforts are made to ensure similar functionality across Bash and Zsh versions where applicable, adapting to shell-specific syntax when necessary (e.g., dynamic script path resolution in `cmd.zsh`).
*   **Prerequisites:** External tools like `nkf` and `fzf` are checked for availability within the scripts, and users are prompted to install them if missing.
*   **Documentation:** The `README.md` file serves as comprehensive user documentation, detailing each script's purpose, prerequisites, and expected output.
*   **Git Commit Conventions:** Follow these prefixes for commit messages:
    *   `Add: `: Adding a new script.
    *   `Update: `: Updating an existing script.
    *   `Delete: `: Deleting an existing script.
    *   `Chore: `: Changes to non-script files (e.g., README, documentation, or other configuration files).

---

## Mandatory Special Rules

*   **Documentation Consistency**: If anything within the repository (code, files, etc.) is added, edited, or deleted, it is imperative to verify that these changes do not contradict the project's documentation. Should any inconsistencies be found, the user must be clearly informed, and then asked if they wish to proceed with updating the documentation to reflect the current state. The documentation should only be updated if the user explicitly grants permission.
*   **Language for AGENTS.md/GEMINI.md**: All content added to `AGENTS.md` and `GEMINI.md` must be written in English.
*   **Post-Change Security Review**: After every change, perform a security check under the assumption that the content may be exposed in a public repository. Report the security review result clearly to the user.

---

## Additional Notes

*   **Encoding Scripts Usage:** The `check-encode` and `convert-encode` scripts are designed to be used in conjunction. When modifying or writing documentation for these scripts (e.g., in `README.md`), ensure their descriptions are placed consecutively and highlight their combined usage.
