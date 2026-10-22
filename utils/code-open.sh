#!/usr/bin/env bash
# code-open — open files in VSCode together with their project folder, and keep
# the desktop's file associations for a user-editable set of extensions.
#
#   code-open FILE...   open each file in the window of its project folder: the
#                       nearest ancestor holding a `.ai` (a context scope), else
#                       the file's own directory
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
  # drop defaults from an earlier sync so a removed extension is released
  [[ -f $MIMEAPPS ]] && sed -i "/^[^=]*=$ENTRY;\?\$/d" "$MIMEAPPS"
  update-desktop-database "$APPS"
  (( ${#mimes[@]} )) && xdg-mime default "$ENTRY" "${mimes[@]}"
  echo "VSCode is the default for: ${mimes[*]}"
}

case $1 in
  --sync) sync_associations ;;
  *)      open_files "$@" ;;
esac
