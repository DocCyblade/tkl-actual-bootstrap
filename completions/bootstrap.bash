

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Bash completion for: bootstrap.sh (tkl-actual-bootstrap)
# Safe and side-effect free. No external dependencies required.
#
# Install system-wide:
#   sudo install -m 0644 completions/bootstrap.bash /etc/bash_completion.d/tkl-actual-bootstrap
# Reload for current shell:
#   . /etc/bash_completion 2>/dev/null || . /usr/share/bash-completion/bash_completion 2>/dev/null || true
#
# Notes:
# - Bash binds completion to the exact token used to invoke the command.
#   We register for both 'bootstrap.sh' and './scripts/bootstrap.sh'.
# -----------------------------------------------------------------------------

[[ -n "${BASH_VERSION:-}" ]] || return 0

_tklab_bootstrap()
{
  local cur prev words cword
  if declare -F _get_comp_words_by_ref >/dev/null 2>&1; then
    _get_comp_words_by_ref -n : cur prev words cword
  else
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  # Keep this list in sync with scripts/bootstrap.sh
  local opts="
    --yes -y --dry-run
    --domain --install-version --ctl-path
    --help --version
    --update-install --with-units --with-nginx --update-install-all
  "

  # Dynamic candidates (quiet if paths don't exist)
  local versions domain_hint
  versions=$(ls -1d /srv/app/v* 2>/dev/null | xargs -r -n1 basename | sort -V)
  if [[ -r /etc/actual-budget/env ]]; then
    domain_hint=$(awk -F= '/^BUDGET_DOMAIN=/{gsub(/\r/,"");gsub(/^[ \t"]+|[ \t"]+$/,"",$2);print $2}' /etc/actual-budget/env)
  fi

  # Value completions for options that take args
  case "$prev" in
    --install-version)
      COMPREPLY=( $(compgen -W "$versions" -- "$cur") )
      return 0
      ;;
    --domain)
      if [[ -n "$domain_hint" ]]; then
        COMPREPLY=( $(compgen -W "$domain_hint" -- "$cur") )
      else
        COMPREPLY=()
      fi
      return 0
      ;;
    --ctl-path)
      COMPREPLY=( $(compgen -f -- "$cur") )
      return 0
      ;;
  esac

  # Otherwise suggest flags
  COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

# Register for common invocation tokens
complete -F _tklab_bootstrap bootstrap.sh
complete -F _tklab_bootstrap ./scripts/bootstrap.sh