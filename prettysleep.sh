#!/usr/bin/env bash

# # 🏳️‍🌈 Opinionated Queer License v1.2
#
# © Copyright [NamelessNanashi](<https://git.NamelessNanashi.dev/>)
#
# ## Permissions
#
# The creators of this Work (“The Licensor”) grant permission
# to any person, group or legal entity that doesn't violate the prohibitions below (“The User”),
# to do everything with this Work that would otherwise infringe their copyright or any patent claims,
# subject to the following conditions:
#
# ## Obligations
#
# The User must give appropriate credit to the Licensor,
# provide a copy of this license or a (clickable, if the medium allows) link to
# [oql.avris.it/license/v1.2](<https://oql.avris.it/license/v1.2>),
# and indicate whether and what kind of changes were made.
# The User may do so in any reasonable manner,
# but not in any way that suggests the Licensor endorses the User or their use.
#
# ## Prohibitions
#
# No one may use this Work for prejudiced or bigoted purposes, including but not limited to:
# racism, xenophobia, queerphobia, queer exclusionism, homophobia, transphobia, enbyphobia, misogyny.
#
# No one may use this Work to inflict or facilitate violence or abuse of human rights,
# as defined in either of the following documents:
# [Universal Declaration of Human Rights](<https://www.un.org/en/about-us/universal-declaration-of-human-right>),
# [European Convention on Human Rights](<https://prd-echr.coe.int/web/echr/european-convention-on-human-rights>)
# along with the rulings of the [European Court of Human Rights](<https://www.echr.coe.int/>).
#
# No law enforcement, carceral institutions, immigration enforcement entities, military entities or military contractors
# may use the Work for any reason. This also applies to any individuals employed by those entities.
#
# No business entity where the ratio of pay (salaried, freelance, stocks, or other benefits)
# between the highest and lowest individual in the entity is greater than 50 : 1
# may use the Work for any reason.
#
# No private business run for profit with more than a thousand employees
# may use the Work for any reason.
#
# Unless the User has made substantial changes to the Work,
# or uses it only as a part of a new work (eg. as a library, as a part of an anthology, etc.),
# they are prohibited from selling the Work.
# That prohibition includes processing the Work with machine learning models.
#
# ## Sanctions
#
# If the Licensor notifies the User that they have not complied with the rules of the license,
# they can keep their license by complying within 30 days after the notice.
# If they do not do so, their license ends immediately.
#
# ## Warranty
#
# This Work is provided “as is”, without warranty of any kind, express or implied.
# The Licensor will not be liable to anyone for any damages related to the Work or this license,
# under any kind of legal claim as far as the law allows.

# prettysleep: human-friendly sleep with a live countdown.
# - Accepts chained duration segments like "1d 2h 10m 5.5s" (spaces optional).
# - Rounds to nearest second and displays "Sleeping: N" when attached to a TTY.
# - Restores cursor and cleans the line on exit or interruption.

# Handle -h/--help early and exit without side effects.
for __arg in "$@"; do
  if [[ "$__arg" == "-h" || "$__arg" == "--help" ]]; then
    cat <<'EOF'
Usage: prettysleep [--help] [--update] <duration>

Accepts chained duration segments (with or without spaces):
  90s
  2m30s
  1h2s
  1d4h
  "1d 2h 10m 5.5s"
  45                (bare seconds)

Units (case-insensitive):
  s  seconds
  m  minutes
  h  hours
  d  days

Behavior:
  • Rounds to the nearest whole second.
  • Shows a single updating "Sleeping: N" line while running.
  • Clears the line on completion; on Ctrl-C/TERM it clears the line and prints a newline.
  • If stdout is not a TTY (piped/redirected), it sleeps silently.

Exit codes:
  0   success
  130 interrupted by Ctrl-C (SIGINT)
  143 terminated by SIGTERM

Examples:
  prettysleep 2m30s
  prettysleep "1d 2h 10m"
  prettysleep 45
EOF
    exit 0
  fi
done

# Check for --update option among the arguments
for arg in "$@"; do
  if [ "$arg" == "--update" ]; then
    update="true"
    TEMPD=$(mktemp -d)
    target="$TEMPD/install.sh"
    url="https://github.com/NanashiTheNameless/prettysleep/raw/refs/heads/main/install.sh"
    echo "Successfully created the temporary directory \"$TEMPD\"!"
    # Prefer axel, then curl, then wget
    if command -v axel >/dev/null 2>&1; then
      axel -H 'DNT: 1' -H 'Sec-GPC: 1' -q -o "$target" "$url"
    elif command -v curl >/dev/null 2>&1; then
      curl -H 'DNT: 1' -H 'Sec-GPC: 1' -fsSL -o "$target" "$url"
    elif command -v wget >/dev/null 2>&1; then
      wget -H 'DNT: 1' -H 'Sec-GPC: 1' -q -O "$target" "$url"
    else
      echo "Need one of: axel, curl, or wget." >&2
      if [ -n "$TEMPD" ]; then
        case "$TEMPD" in
          /tmp/*)
            if command rm -rf "$TEMPD"; then
              echo "Cleaned up temporary directory \"$TEMPD\" successfully!"
              fi
              ;;
          *)
            echo "Warning: TEMPD=\"$TEMPD\" is outside /tmp/, refusing to delete for safety."
            ;;
        esac
      fi
      if [ -e "$TEMPD" ]; then
        echo "Temp Directory \"$TEMPD\" was not deleted correctly; you need to manually remove it!"
      fi
      exit 1
    fi
    chmod +x $TEMPD/install.sh ;
    bash $TEMPD/install.sh --agree ;
    if [ -n "$TEMPD" ]; then
      case "$TEMPD" in
        /tmp/*)
          if command rm -rf "$TEMPD"; then
            echo "Cleaned up temporary directory \"$TEMPD\" successfully!"
          fi
          ;;
        *)
          echo "Warning: TEMPD=\"$TEMPD\" is outside /tmp/, refusing to delete for safety."
          ;;
      esac
    fi
    if [ -e "$TEMPD" ]; then
      echo "Temp Directory \"$TEMPD\" was not deleted correctly; you need to manually remove it!"
    fi
    break
  fi
done

# Exit after completing --update
if [ "$update" = true ]; then
    exit 0
fi

# Join all arguments, then strip all whitespace to allow inputs like "1d 2h".
input="$*"
input="${input//[[:space:]]/}"

# Basic usage check.
if [[ -z "$input" ]]; then
  echo 'Usage: prettysleep [--help] [--update] <duration>  (try: 90s, 2m30s, 1h2s, 1d4h, "1d 2h 10m")' >&2
  exit 1
fi

# Accumulator (in whole seconds) and the unparsed remainder.
total_secs=0
rest="$input"

# Regex captures a numeric part (int/float) followed by a unit [s|m|h|d], case-insensitive.
re='^([0-9]*\.?[0-9]+)([smhdSMHD])'

# Parse chained segments greedily from the start of "rest".
while [[ "$rest" =~ $re ]]; do
  num="${BASH_REMATCH[1]}"
  unit="${BASH_REMATCH[2]}"

  # Map unit to seconds multiplier.
  case "$unit" in
    s|S) factor=1 ;;
    m|M) factor=60 ;;
    h|H) factor=3600 ;;
    d|D) factor=86400 ;;
    *) echo "Unsupported time unit: $unit" >&2; exit 1 ;;
  esac

  # Round num*factor to the nearest whole second via awk printf("%.0f").
  seg="$(awk -v n="$num" -v f="$factor" 'BEGIN{printf "%.0f\n", n*f}')"
  total_secs=$(( total_secs + seg ))

  # Consume the matched prefix and continue parsing.
  rest="${rest:${#BASH_REMATCH[0]}}"
done

# If anything remains, it must be a bare number (seconds). Otherwise it's invalid.
if [[ -n "$rest" ]]; then
  if [[ "$rest" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    seg="$(awk -v n="$rest" 'BEGIN{printf "%.0f\n", n}')"
    total_secs=$(( total_secs + seg ))
  else
    echo "Unsupported time format: $*" >&2
    exit 1
  fi
fi

# Zero or negative durations are treated as no-op success.
if (( total_secs <= 0 )); then
  exit 0
fi

# If stdout is not a TTY (e.g., piped), perform a plain sleep without UI.
if [[ ! -t 1 ]]; then
  sleep "$total_secs"
  exit $?
fi

# Hide cursor for a cleaner single-line UI (ESC[?25l); shown again on exit.
printf '\e[?25l'

# Ensure we only restore once, even if multiple traps fire.
__PS_CLEANED=""

# On SIGINT (Ctrl-C): clear line, show cursor, newline, and exit 130.
trap 'if [[ -z "$__PS_CLEANED" ]]; then printf "\r\033[2K"; printf "\e[?25h"; __PS_CLEANED=1; fi; printf "\n"; exit 130' INT
# On SIGTERM: clear line, show cursor, newline, and exit 143.
trap 'if [[ -z "$__PS_CLEANED" ]]; then printf "\r\033[2K"; printf "\e[?25h"; __PS_CLEANED=1; fi; printf "\n"; exit 143' TERM
# On normal exit: clear line and show cursor (no newline).
trap 'if [[ -z "$__PS_CLEANED" ]]; then printf "\r\033[2K"; printf "\e[?25h"; __PS_CLEANED=1; fi' EXIT

# Countdown UI: overwrite the same line using CR (\r) and clear-to-end (ESC[0K).
while (( total_secs > 0 )); do
  printf '\rSleeping: %s\033[0K' "$total_secs"
  sleep 1
  (( total_secs-- ))
done

# Success exit.
exit 0
