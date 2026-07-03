#!/usr/bin/env bash
# usb-mount-prompt — on newly-connected USB storage: ask Read-only / Read-write / Don't mount,
# mount via udisksctl, then open the file manager at the mount point.
LOG="$HOME/usb-mount-prompt.log"
log(){ printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG"; }
log "==== started pid $$  WAYLAND=${WAYLAND_DISPLAY:-none} ===="
command -v zenity    >/dev/null 2>&1 || { log "no zenity — exit";   exit 0; }
command -v udisksctl >/dev/null 2>&1 || { log "no udisksctl — exit"; exit 0; }
US=$'\x1f'

declare -A SEEN
list_usb_fs() {
  lsblk -Ppo NAME,FSTYPE,TRAN,HOTPLUG,MOUNTPOINT,SIZE,LABEL 2>/dev/null | while IFS= read -r l; do
    n=$(sed -n 's/^NAME="\([^"]*\)".*/\1/p' <<<"$l")
    fs=$(sed -n 's/.* FSTYPE="\([^"]*\)".*/\1/p' <<<"$l")
    tr=$(sed -n 's/.* TRAN="\([^"]*\)".*/\1/p' <<<"$l")
    hp=$(sed -n 's/.* HOTPLUG="\([^"]*\)".*/\1/p' <<<"$l")
    mp=$(sed -n 's/.* MOUNTPOINT="\([^"]*\)".*/\1/p' <<<"$l")
    sz=$(sed -n 's/.* SIZE="\([^"]*\)".*/\1/p' <<<"$l")
    lb=$(sed -n 's/.* LABEL="\([^"]*\)".*/\1/p' <<<"$l")
    { [ "$tr" = usb ] || [ "$hp" = 1 ]; } && [ -n "$fs" ] || continue
    printf '%s%s%s%s%s%s%s%s%s\n' "$n" "$US" "$fs" "$US" "$mp" "$US" "$sz" "$US" "$lb"
  done
}
prompt_and_mount() {
  local dev="$1" fs="$2" size="$3" label="$4" choice opts mp
  findmnt -S "$dev" >/dev/null 2>&1 && { log "  $dev already mounted, skip"; return; }
  choice=$(zenity --list --radiolist --title="Removable disk connected" \
    --text="${label:-$dev}   ($size, $fs)" \
    --column="" --column="Option" TRUE "Read-only" FALSE "Read-write" FALSE "Don't mount" \
    --width=400 --height=220 2>>"$LOG")
  case "$choice" in
    "Read-only")  opts="ro,noexec,nosuid,nodev" ;;
    "Read-write") opts="rw,nosuid,nodev" ;;
    *) log "  '$choice' — not mounting"; return ;;
  esac
  # mount (fall back to just ro/rw if udisks rejects the full option set)
  udisksctl mount -b "$dev" -o "$opts" >>"$LOG" 2>&1 \
    || udisksctl mount -b "$dev" -o "${opts%%,*}" >>"$LOG" 2>&1 \
    || udisksctl mount -b "$dev" >>"$LOG" 2>&1
  mp=$(findmnt -fno TARGET "$dev" 2>/dev/null | head -1)
  if [ -n "$mp" ]; then
    log "  mounted at $mp — opening file manager"
    xdg-open "$mp" >>"$LOG" 2>&1 &
  else
    log "  mount failed for $dev"
  fi
}
while IFS="$US" read -r n _; do [ -n "$n" ] && SEEN["$n"]=1; done < <(list_usb_fs)
log "pre-seed done (${#SEEN[@]}); watching..."
while true; do
  while IFS="$US" read -r n fs mp sz lb; do
    [ -n "$n" ] || continue
    if [ -z "${SEEN[$n]:-}" ]; then
      log "NEW: $n fs=$fs mp='$mp' size=$sz label='$lb'"; SEEN["$n"]=1
      [ -z "$mp" ] && prompt_and_mount "$n" "$fs" "$sz" "$lb" &
    fi
  done < <(list_usb_fs)
  for k in "${!SEEN[@]}"; do [ -b "$k" ] || { unset 'SEEN[$k]'; log "unplugged: $k"; }; done
  sleep 2
done
