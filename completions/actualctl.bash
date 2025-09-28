#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Bash completion for: actualctl
# Installs to: /etc/bash_completion.d/actualctl
# Source locally: . /path/to/completions/actualctl.bash
#
# Safe, side‑effect free: only lists /srv/*/data and /srv/app/v*
# -----------------------------------------------------------------------------

_actualctl()
{
  local cur prev words cword
  # Prefer helper when bash-completion is loaded
  if declare -F _get_comp_words_by_ref >/dev/null 2>&1; then
    _get_comp_words_by_ref -n : cur prev words cword
  else
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  # Top-level commands (keep in sync with scripts/actualctl)
  local cmds=(
    help --help -h
    version --version
    list check env health doctor
    fetch switch verify
    backup restore prune-backups prune-versions
    instance service logs
  )
  local inst_sub=(add rm set-port)
  local svc_ops=(start stop restart status)

  # Dynamic candidates (no side-effects)
  local instances versions
  instances=$(ls -1d /srv/*/data 2>/dev/null | sed -E 's|/srv/([^/]+)/data|\1|' | sort -u)
  versions=$(ls -1d /srv/app/v* 2>/dev/null | xargs -r -n1 basename | sort -V)

  # First arg → suggest subcommands
  if (( cword == 1 )); then
    COMPREPLY=( $(compgen -W "${cmds[*]}" -- "$cur") )
    return 0
  fi

  # Dispatch on the first subcommand
  case "${words[1]}" in
    env|health|logs|service|backup|restore)
      case "${words[1]}" in
        service)
          # actualctl service <INST> <op>
          if (( cword == 2 )); then
            COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
          else
            COMPREPLY=( $(compgen -W "${svc_ops[*]}" -- "$cur") )
          fi
          ;;
        logs)
          # actualctl logs <INST> [lines]
          if (( cword == 2 )); then
            COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
          fi
          ;;
        backup|env|health)
          # actualctl <cmd> [INST]  (empty means "all")
          COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
          ;;
        restore)
          # actualctl restore <INST> <tgz>
          if (( cword == 2 )); then
            COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
          else
            COMPREPLY=( $(compgen -f -X '!*.tgz' -- "$cur") )
          fi
          ;;
      esac
      ;;

    fetch|verify)
      # actualctl fetch/verify <vX.Y.Z>
      COMPREPLY=( $(compgen -W "$versions" -- "$cur") )
      ;;

    switch)
      # actualctl switch <INST> <vX.Y.Z>
      if (( cword == 2 )); then
        COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "$versions" -- "$cur") )
      fi
      ;;

    prune-backups)
      # actualctl prune-backups [--keep N]
      if [[ "$prev" == "--keep" ]]; then
        COMPREPLY=( $(compgen -W "3 5 7 10 14 30" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "--keep" -- "$cur") )
      fi
      ;;
    prune-versions)
      # actualctl prune-versions [--dry-run] [--keep N] [--older-than DAYS]
      case "$prev" in
        --keep)
          COMPREPLY=( $(compgen -W "1 2 3 5 7 10" -- "$cur") )
          ;;
        --older-than)
          COMPREPLY=( $(compgen -W "7 14 21 30 60 90" -- "$cur") )
          ;;
        *)
          COMPREPLY=( $(compgen -W "--dry-run --keep --older-than" -- "$cur") )
          ;;
      esac
      ;;

    instance)
      # actualctl instance <add|rm|set-port> ...
      if (( cword == 2 )); then
        COMPREPLY=( $(compgen -W "${inst_sub[*]}" -- "$cur") )
      else
        case "${words[2]}" in
          add)
            # actualctl instance add <NAME> <ver|development|test|production> [--from SRC] [--port PORT]
            case $cword in
              3) ;; # free-form NAME
              4) COMPREPLY=( $(compgen -W "$versions development test production" -- "$cur") ) ;;
              *) COMPREPLY=( $(compgen -W "--from --port" -- "$cur") ) ;;
            esac
            ;;
          rm)
            # actualctl instance rm <NAME> [--purge]
            if (( cword == 3 )); then
              COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
            else
              COMPREPLY=( $(compgen -W "--purge" -- "$cur") )
            fi
            ;;
          set-port)
            # actualctl instance set-port <NAME> <PORT>
            if (( cword == 3 )); then
              COMPREPLY=( $(compgen -W "$instances" -- "$cur") )
            fi
            ;;
        esac
      fi
      ;;

    *)
      COMPREPLY=()
      ;;
  esac
}

# Register completion
complete -F _actualctl actualctl