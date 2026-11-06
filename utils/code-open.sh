#!/usr/bin/env bash
# code-open — open files in VSCode together with their project folder, and keep
# the desktop's file associations for a user-editable set of extensions.
#
#   code-open FILE...   open each file in the window of its project folder: the
#                       nearest ancestor holding a `.ai` (a context scope), else
#                       the file's own directory
#   code-open --url URL open a vscode://file/<path>[:line[:col]] link the same way
#                       (what a chat link click runs); any other vscode:// URL is
#                       passed to VSCode's own handler
#   code-open --sync    make VSCode the default app for the extensions listed in
#                       ~/.config/code-open/extensions (one per line, no dot,
#                       `#` comments); writes the config with defaults if absent
#
# Associations are per MIME type, so --sync resolves each extension through the
# system MIME database; an extension that would capture a whole media class or
# every plain-text file is skipped with a warning.

CONF=${XDG_CONFIG_HOME:-$HOME/.config}/code-open/extensions
APPS=${XDG_DATA_HOME:-$HOME/.local/share}/applications
ENTRY=vscode-scope.desktop
URL_ENTRY=vscode-url.desktop
MIMEAPPS=${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list
DEFAULT_EXTS='md markdown sh bash zsh py js mjs ts tsx jsx json yaml yml toml rs go c h cpp hpp java rb php lua sql css scss'

scope_of() {
  local dir=$1
  while [[ $dir != / && $dir != $HOME ]]; do
    [[ -e $dir/.ai ]] && { printf '%s\n' "$dir"; return; }
    dir=$(dirname -- "$dir")
  done
  printf '%s\n' "$1"
}

open_files() {
  local f
  for f in "$@"; do
    # -s: keep symlinks unresolved, since a scope's `.ai` is itself a link into the state
    f=$(realpath -s -- "$f") || continue
    /usr/bin/code "$(scope_of "$(dirname -- "$f")")" -g "$f"
  done
}

# open_url URL — vscode://file/<path>[:line[:col]] opens like open_files with the
# position kept; every other vscode:// URL (auth callbacks, extension installs)
# goes to the stock handler untouched.
open_url() {
  local url=$1 rest path pos=
  if [[ $url != vscode://file/* ]]; then
    exec /usr/share/code/code --open-url "$url"
  fi
  rest=${url#vscode://file}
  rest=${rest%%[?#]*}
  rest=$(printf '%b' "${rest//%/\\x}")        # URL-decode
  if [[ $rest =~ ^(.*[^/]):([0-9]+(:[0-9]+)?)$ ]]; then
    path=${BASH_REMATCH[1]} pos=:${BASH_REMATCH[2]}
  else
    path=$rest
  fi
  path=$(realpath -s -- "$path") || exit 1
  /usr/bin/code "$(scope_of "$(dirname -- "$path")")" -g "$path$pos"
}

sync_associations() {
  local tmp ext mime mimes=()
  if [[ ! -f $CONF ]]; then
    mkdir -p "$(dirname "$CONF")"
    { echo '# Extensions VSCode opens by default (one per line, no dot); run `code-open --sync` after editing.'
      printf '%s\n' $DEFAULT_EXTS; } > "$CONF"
    echo "wrote $CONF"
  fi
  tmp=$(mktemp -d) || return 1
  while read -r ext; do
    ext=${ext%%#*}; ext=${ext//[[:space:]]/}; ext=${ext#.}
    [[ -n $ext ]] || continue
    : > "$tmp/x.$ext"
    mime=$(xdg-mime query filetype "$tmp/x.$ext")
    case $mime in
      ''|text/plain|video/*|audio/*|image/*)
        echo "skipped .$ext: resolves to '${mime:-nothing}', too broad to claim" >&2; continue ;;
    esac
    [[ " ${mimes[*]} " == *" $mime "* ]] || mimes+=("$mime")
  done < "$CONF"
  rm -r "$tmp"

  mkdir -p "$APPS"
  cat > "$APPS/$ENTRY" <<EOT
[Desktop Entry]
Name=VS Code (file + folder)
Comment=Open a file in VSCode together with its project folder
Exec=$HOME/.local/bin/code-open %F
Icon=vscode
Type=Application
Terminal=false
Categories=Utility;TextEditor;Development;
MimeType=$(IFS=';'; echo "${mimes[*]};")
NoDisplay=true
EOT
  cat > "$APPS/$URL_ENTRY" <<EOT
[Desktop Entry]
Name=VS Code (links, file + folder)
Comment=Open vscode://file links in the window of the file's project folder
Exec=$HOME/.local/bin/code-open --url %u
Icon=vscode
Type=Application
Terminal=false
Categories=Utility;TextEditor;Development;
MimeType=x-scheme-handler/vscode;
NoDisplay=true
EOT
  # drop defaults from an earlier sync so a removed extension is released
  [[ -f $MIMEAPPS ]] && sed -i "/^[^=]*=$ENTRY;\?\$/d" "$MIMEAPPS"
  update-desktop-database "$APPS"
  (( ${#mimes[@]} )) && xdg-mime default "$ENTRY" "${mimes[@]}"
  xdg-mime default "$URL_ENTRY" x-scheme-handler/vscode
  echo "VSCode is the default for: ${mimes[*]}"
}

case $1 in
  --sync) sync_associations ;;
  --url)  open_url "$2" ;;
  *)      open_files "$@" ;;
esac
