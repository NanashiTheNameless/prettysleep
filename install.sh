#!/usr/bin/env bash
# Prettysleep installer
# - Installs to $HOME/.local/bin (override via DIR)
# - Requires accepting OQL v1.2 (or pass --agree)
# - Removes older installs, downloads latest, sets execute bit
# - Ensures $DIR is added to PATH in common shell init files

# Installation target directory
DIR="$HOME/.local/bin"

# Parse flags (only --agree is recognized)
AGREE_FLAG=0
for __arg in "$@"; do
  if [[ "$__arg" == "--agree" ]]; then
    AGREE_FLAG=1
  fi
done

# Show license text (do not edit)
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

# Confirm license agreement if --agree was not supplied
if [[ $AGREE_FLAG -eq 1 ]]; then
  echo "Agreement provided via --agree."
else
  # Read from /dev/tty when available to avoid piping issues
  if [ -t 0 ] && [ -r /dev/tty ]; then
    printf "\nDo you agree to the license terms above? [y/N]: " > /dev/tty
    read -r REPLY < /dev/tty || REPLY=""
  else
    printf "\nDo you agree to the license terms above? [y/N]: "
    read -r REPLY || REPLY=""
  fi

  # Accept only y/yes (case-insensitive)
  case "$REPLY" in
    [yY]|[yY][eE][sS]) echo "Agreed." ;;
    *)                 echo "Not agreed."; exit 1 ;;
  esac
fi

# Append PATH export to a shell init file if $DIR is not already present
check_and_add_to_file() {
  local file=$1
  # Detect an existing PATH entry referencing $DIR; otherwise append one
  if cat $file | grep PATH | grep -Fq "$DIR"; then
    echo "$DIR is already in the PATH in $file"
  else
    echo "Adding $DIR to $file"
    echo "" >> "$file"
    echo "export PATH=\"$DIR:\$PATH\"" >> "$file"
  fi
}

# Create the target directory if missing
makedir() {
  if [ ! -d "$DIR" ]; then
    echo "$DIR does not exist. Creating directory..."
    mkdir -p "$DIR"
  fi
}

# Remove older installs in $DIR and optionally from /usr/bin
removeold() {
  # Delete any previous local copies quietly
  for name in "$DIR/prettysleep" "$DIR/prettysleep.sh"; do
    if [ -f "$name" ]; then
      echo "Removing old version $name"
      command rm -f -- "$name"
    fi
  done

  # Offer to remove system-wide copies (requires sudo)
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

# Download latest script and verify basic integrity
installlatest() {
  local url="https://github.com/NanashiTheNameless/prettysleep/raw/refs/heads/main/prettysleep.sh"
  local target="$DIR/prettysleep"

  echo "Downloading $url → $target"

  # Prefer axel, then curl, then wget
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

  # Verify file is non-empty and starts with a bash shebang
  if ! [ -s "$target" ]; then
    echo "Download failed or empty file: $target" >&2
    exit 1
  fi
  if ! head -n1 "$target" | grep -q '^#!/usr/bin/env bash'; then
    echo "Downloaded file doesn't look like the expected script (missing bash shebang)." >&2
    exit 1
  fi
}

# Ensure the installed script is executable; escalate if needed
makeexecutable() {
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

# Add $DIR to PATH in .zshrc and .bashrc when those files exist
handlepath() {
  [ -f "$HOME/.zshrc" ]  && check_and_add_to_file "$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && check_and_add_to_file "$HOME/.bashrc"
}

# Execute installation steps in order
makedir
removeold
installlatest
makeexecutable
handlepath

echo "Installation complete!"
