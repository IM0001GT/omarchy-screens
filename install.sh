#!/bin/bash

# Enable Screens on the Omarchy bar.
#
# Preferred:
#   omarchy plugin add https://github.com/IM0001GT/omarchy-screens --enable

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="im0001gt.screens"

usage() {
  cat <<'EOF'
Usage: ./install.sh [-h|--help]

Enable or update Screens and place it on the right side of the bar,
next to the stock Display widget.

Preferred install:

  omarchy plugin add https://github.com/IM0001GT/omarchy-screens --enable
EOF
}

while (( $# > 0 )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -n ${SUDO_USER:-} ]]; then
  real_user="$SUDO_USER"
else
  real_user="${USER:-$(id -un)}"
fi
real_home="$(getent passwd "$real_user" | cut -d: -f6 2>/dev/null || true)"
if [[ -z $real_home || ! -d $real_home ]]; then
  echo "error: cannot resolve home directory for user '$real_user'" >&2
  exit 1
fi

if [[ $(id -u) -eq 0 ]]; then
  run_as_user() { runuser -u "$real_user" -- "$@"; }
else
  run_as_user() { "$@"; }
fi

for cmd in jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: missing required command: $cmd" >&2; exit 1; }
done
[[ -f $SCRIPT_DIR/manifest.json && -f $SCRIPT_DIR/Screens.qml && -x $SCRIPT_DIR/scripts/display-ctl ]] \
  || { echo "error: plugin sources not found next to this script" >&2; exit 1; }

plugin_dir="$real_home/.config/omarchy/plugins/$PLUGIN_ID"
ctl="$SCRIPT_DIR/scripts/display-ctl"

# Snapshot stock files before Screens copies or writes anything.
# Survives plugin remove. Restore with: display-ctl restore-original
# or ~/.local/state/im0001gt.screens/restore.sh
if [[ -x $ctl ]] && run_as_user "$ctl" backup-original >/dev/null; then
  echo "Kept your current Hyprland and Omarchy files in ~/.local/state/im0001gt.screens/originals/"
fi

copy_plugin_files() {
  echo "Installing plugin files to $plugin_dir ..."
  mkdir -p "$plugin_dir/scripts"
  install -m 0644 "$SCRIPT_DIR/manifest.json" "$plugin_dir/manifest.json"
  install -m 0644 "$SCRIPT_DIR/Screens.qml" "$plugin_dir/Screens.qml"
  install -m 0644 "$SCRIPT_DIR/ScreenMark.qml" "$plugin_dir/ScreenMark.qml"
  install -m 0644 "$SCRIPT_DIR/Model.js" "$plugin_dir/Model.js"
  install -m 0644 "$SCRIPT_DIR/Workspaces.qml" "$plugin_dir/Workspaces.qml"
  install -m 0644 "$SCRIPT_DIR/WorkspaceLayoutMenu.qml" "$plugin_dir/WorkspaceLayoutMenu.qml"
  install -m 0644 "$SCRIPT_DIR/Service.qml" "$plugin_dir/Service.qml"
  install -m 0755 "$SCRIPT_DIR/scripts/display-ctl" "$plugin_dir/scripts/display-ctl"
  install -m 0755 "$SCRIPT_DIR/scripts/omarchy-brightness-display" "$plugin_dir/scripts/omarchy-brightness-display"
  install -m 0755 "$SCRIPT_DIR/scripts/display-wake" "$plugin_dir/scripts/display-wake" 2>/dev/null || true
  mkdir -p "$real_home/.local/bin"
  ln -sfn "$plugin_dir/scripts/omarchy-brightness-display" "$real_home/.local/bin/omarchy-brightness-display"
  chown -R "$real_user:" "$plugin_dir" 2>/dev/null || true
}

reload_shell() {
  echo "Restarting omarchy-shell so the new plugin code is loaded ..."
  rm -rf "$real_home/.cache/quickshell/qmlcache" 2>/dev/null || true
  if ! run_as_user omarchy restart shell; then
    echo "warning: could not restart the shell. Run: omarchy restart shell" >&2
  fi
}

if [[ $SCRIPT_DIR == "$plugin_dir" ]]; then
  echo "Already running from the installed plugin directory."
elif [[ -d $plugin_dir/.git ]]; then
  echo "Plugin already installed as a git checkout. Updating ..."
  run_as_user omarchy plugin update "$PLUGIN_ID" --yes || \
    echo "warning: omarchy plugin update failed; restarting with the files already on disk." >&2
elif [[ ! -e $plugin_dir ]]; then
  origin=""
  if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    origin=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
  fi
  if [[ -n $origin ]] && run_as_user omarchy plugin add "$origin" --yes; then
    echo "Added $PLUGIN_ID from $origin"
  else
    copy_plugin_files
  fi
else
  copy_plugin_files
fi

[[ -x $plugin_dir/scripts/display-ctl ]] && ctl="$plugin_dir/scripts/display-ctl"

confirm() {
  local prompt="$1"
  if [[ -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
    gum confirm "$prompt"
    return
  fi
  if [[ -t 0 && -t 1 ]]; then
    local reply=""
    read -r -p "$prompt [y/N] " reply
    [[ $reply == y || $reply == Y || $reply == yes ]]
    return
  fi
  return 1
}

if [[ -x $ctl ]]; then
  if conflict_json=$(run_as_user "$ctl" conflicts --check 2>/dev/null); then
    :
  else
    echo
    echo "hyprmoncfg is still installed. It stays in control of screen settings"
    echo "until it is removed — Screens will yield until then."
    if [[ -n $conflict_json ]]; then
      echo "$conflict_json" | jq -r '.message // empty' 2>/dev/null || true
    fi
    echo
    if confirm "Remove the hyprmoncfg plugin and stop its daemon now?"; then
      run_as_user "$ctl" conflicts remove || \
        echo "warning: could not fully remove hyprmoncfg; Screens will keep yielding." >&2
    else
      echo "Leaving hyprmoncfg in place. Remove it later with:"
      echo "  omarchy plugin remove crmne.hyprmoncfg"
      echo "  systemctl --user disable --now hyprmoncfgd.service"
    fi
  fi
  echo "Taking over monitors.lua from the live layout (original stays in the backup) ..."
  run_as_user "$ctl" claim >/dev/null || \
    echo "warning: could not claim monitors.lua yet; open Screens once after the shell restarts." >&2
fi

run_as_user omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

discovered=0
for (( attempt = 0; attempt < 60; attempt++ )); do
  if run_as_user omarchy-plugin-catalog 2>/dev/null | jq -e --arg id "$PLUGIN_ID" \
      'any(.[]; .id == $id)' >/dev/null 2>&1; then
    discovered=1
    break
  fi
  sleep 0.1
done
if (( ! discovered )); then
  echo "warning: plugin not discovered yet; enabling anyway." >&2
fi

echo "Placing Screens next to the stock Display widget ..."
if ! run_as_user omarchy plugin enable "$PLUGIN_ID" --after omarchy.monitor; then
  run_as_user omarchy plugin enable "$PLUGIN_ID" --section right
fi

reload_shell

echo
echo "Done. Screens is a bar widget — click the two-tile icon."
echo "  Drag tiles to arrange. Edges snap flush; stacked tiles also get a light center snap."
echo "  Per screen: brightness, resolution, refresh, HDR, VRR, scale, rotation."
echo "  Desktop: text size."
echo "  Scale keys: Super+/ up, Super+Alt+/ down."
echo "  Uninstall:"
echo "    $plugin_dir/scripts/display-ctl restore-original"
echo "    omarchy plugin remove $PLUGIN_ID"
echo "  If the plugin is already gone:"
echo "    ~/.local/state/im0001gt.screens/restore.sh"
