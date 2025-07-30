#!/usr/bin/env bash

# Set directory to install prettysleep to
DIR="$HOME/.local/bin"

# Parse flags (currently only --agree)
AGREE_FLAG=0
for __arg in "$@"; do
  if [[ "$__arg" == "--agree" ]]; then
    AGREE_FLAG=1
  fi
done

# --- echo the license --------------------------------------------------------
cat <<'LICENSE'
# 🏳️‍🌈 Opinionated Queer License v1.2

© Copyright [NamelessNanashi](<https://git.NamelessNanashi.dev/>)

## Permissions

The creators of this Work (“The Licensor”) grant permission
to any person, group or legal entity that doesn't violate the prohibitions below (“The User”),
to do everything with this Work that would otherwise infringe their copyright or any patent claims,
subject to the following conditions:

## Obligations

The User must give appropriate credit to the Licensor,
provide a copy of this license or a (clickable, if the medium allows) link to
[oql.avris.it/license/v1.2](<https://oql.avris.it/license/v1.2>),
and indicate whether and what kind of changes were made.
The User may do so in any reasonable manner,
but not in any way that suggests the Licensor endorses the User or their use.

## Prohibitions

No one may use this Work for prejudiced or bigoted purposes, including but not limited to:
racism, xenophobia, queerphobia, queer exclusionism, homophobia, transphobia, enbyphobia, misogyny.

No one may use this Work to inflict or facilitate violence or abuse of human rights,
as defined in either of the following documents:
[Universal Declaration of Human Rights](<https://www.un.org/en/about-us/universal-declaration-of-human-right>),
[European Convention on Human Rights](<https://prd-echr.coe.int/web/echr/european-convention-on-human-rights>)
along with the rulings of the [European Court of Human Rights](<https://www.echr.coe.int/>).

No law enforcement, carceral institutions, immigration enforcement entities, military entities or military contractors
may use the Work for any reason. This also applies to any individuals employed by those entities.

No business entity where the ratio of pay (salaried, freelance, stocks, or other benefits)
between the highest and lowest individual in the entity is greater than 50 : 1
may use the Work for any reason.

No private business run for profit with more than a thousand employees
may use the Work for any reason.

Unless the User has made substantial changes to the Work,
or uses it only as a part of a new work (eg. as a library, as a part of an anthology, etc.),
they are prohibited from selling the Work.
That prohibition includes processing the Work with machine learning models.

## Sanctions

If the Licensor notifies the User that they have not complied with the rules of the license,
they can keep their license by complying within 30 days after the notice.
If they do not do so, their license ends immediately.

## Warranty

This Work is provided “as is”, without warranty of any kind, express or implied.
The Licensor will not be liable to anyone for any damages related to the Work or this license,
under any kind of legal claim as far as the law allows.
LICENSE

# --- prompt for agreement (unless --agree is provided) -----------------------
if [[ $AGREE_FLAG -eq 1 ]]; then
  echo "Agreement provided via --agree."
else
  # Try to prompt on /dev/tty so it still works if stdin is redirected.
  if [ -t 0 ] && [ -r /dev/tty ]; then
    printf "\nDo you agree to the license terms above? [y/N]: " > /dev/tty
    read -r REPLY < /dev/tty || REPLY=""
  else
    printf "\nDo you agree to the license terms above? [y/N]: "
    read -r REPLY || REPLY=""
  fi

  case "$REPLY" in
    [yY]|[yY][eE][sS]) echo "Agreed." ;;   # proceed
    *)                 echo "Not agreed."; exit 1 ;;
  esac
fi

# Function to check and add directory to PATH in a given file
check_and_add_to_file() {
  local file=$1
  [ -n "$file" ] || { echo "target file required" >&2; return 2; }
  [ -n "$DIR" ]  || { echo "DIR is not set" >&2; return 2; }

  local marker="# PATHHELPER: $DIR"

  # If we've already managed this dir in this file, do nothing
  if grep -Fqx "$marker" "$file" 2>/dev/null; then
    echo "$DIR is already managed in $file"
    return 0
  fi

  # Ensure the file exists (no-op if it already does)
  : > "$file"

  {
    echo "$marker"
    echo "if [ -d \"$DIR\" ]; then"
    echo "  case \":\$PATH:\" in"
    echo "    *\":$DIR:\"*) ;;"
    echo "    *) PATH=\"$DIR:\$PATH\" ;;"
    echo "  esac"
    echo "  export PATH"
    echo "fi"
    echo "# END $marker"
  } >> "$file"

  echo "Added $DIR to $file"
}

# Make install directory if it exists
makedir() {
  # Check if the directory exists, create if not
  if [ ! -d "$DIR" ]; then
    echo "$DIR does not exist. Creating directory..."
    mkdir -p "$DIR"
  fi
}

# Remove old version(s) if they exist
removeold() {
  for name in "$DIR/prettysleep" "$DIR/prettysleep.sh"; do
    if [ -f "$name" ]; then
      echo "Removing old version $name"
      command rm -f -- "$name"
    fi
  done

  for name in /usr/bin/prettysleep /usr/bin/prettysleep.sh; do
    if [ -f "$name" ]; then
      printf "Found old system-wide install at %s. Remove it? [y/N]: " "$name"
      read -r REPLY
      case "$REPLY" in
        [yY]|[yY][eE][sS]) sudo rm -f -- "$name" ;;
        *) echo "Keeping $name" ;;
      esac
    fi
  done
}

# Install latest version
installlatest() {
  local url="https://github.com/NanashiTheNameless/prettysleep/raw/refs/heads/main/prettysleep.sh"
  local target="$DIR/prettysleep"

  echo "Downloading $url → $target"

  if command -v axel >/dev/null 2>&1; then
    axel -q -o "$target" "$url"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$target" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$target" "$url"
  else
    echo "Need one of: axel, curl, or wget." >&2
    exit 1
  fi

  # Verify download: non-empty and plausible script (bash shebang)
  if ! [ -s "$target" ]; then
    echo "Download failed or empty file: $target" >&2
    exit 1
  fi
  if ! head -n1 "$target" | grep -q '^#!/usr/bin/env bash'; then
    echo "Downloaded file doesn't look like the expected script (missing bash shebang)." >&2
    exit 1
  fi
}

makeexecutable() {
  # Make latest version runable
  if [ ! -x "$DIR/prettysleep" ]; then
    echo "$DIR/prettysleep is not executable. Attempting to add execute permission."
    chmod +x "$DIR/prettysleep"
    if [ ! -x "$DIR/prettysleep" ]; then
      echo "$DIR/prettysleep is not executable after trying to add permissions, now trying with sudo."
      sudo chmod +x "$DIR/prettysleep"
      if [ ! -x "$DIR/prettysleep" ]; then
        echo "$DIR/prettysleep is still not executable after trying to add permissions with sudo. Something is very wrong, This likely needs to be fixed manually!"
        echo "Try running \"sudo chmod +x $DIR/prettysleep\" or \"chmod +x $DIR/prettysleep\" as root"
        echo "(prettysleep will still be added to your \$PATH variable)"
        handlepath
        exit 1
      else
        echo "$DIR/prettysleep is now executable."
      fi
    else
      echo "$DIR/prettysleep is now executable."
    fi
  else
    echo "$DIR/prettysleep is already executable."
  fi
}

# Handle the Implementation of PATH
handlepath() {
  # Check and modify .zshrc
  [ -f "$HOME/.zshrc" ] && check_and_add_to_file "$HOME/.zshrc"

  # Check and modify .bashrc
  [ -f "$HOME/.bashrc" ] && check_and_add_to_file "$HOME/.bashrc"
}

# Check if the directory exists, create if not
makedir

# Delete old version
removeold

# Install latest version
installlatest

# Make it executable
makeexecutable

# Handle the Implementation of PATH
handlepath

# Announce completion
echo "Installation complete!"
