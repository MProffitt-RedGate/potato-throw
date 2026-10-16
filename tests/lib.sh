# Test harness: a throwaway world with a bare remote and one clone + config dir per Player.
# Tests drive only the ./potato command.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Keep git hermetic: no user signing config, fixed identity.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

WORLDS=()
trap 'rm -rf "${WORLDS[@]}"' EXIT

new_world() {
  WORLD="$(mktemp -d "${TMPDIR:-/tmp}/potato-world.XXXXXX")"
  WORLDS+=("$WORLD")
  git init -q --bare -b main "$WORLD/remote.git"
  # Seed the remote with the script under test, as a maintainer would have.
  local seed="$WORLD/seed"
  git init -q -b main "$seed"
  cp "$REPO_ROOT/potato" "$seed/potato"
  git -C "$seed" add potato
  git -C "$seed" commit -q -m "seed"
  git -C "$seed" remote add origin "$WORLD/remote.git"
  git -C "$seed" push -q origin main
}

# join_machine NAME: give a simulated Player a clone and config dir.
join_machine() {
  git clone -q "$WORLD/remote.git" "$WORLD/$1-clone"
  mkdir -p "$WORLD/$1-config"
}

# run_as MACHINE [INPUT]: run ./potato on that machine with scripted stdin.
run_as() {
  local m="$1" input="${2-}"
  (cd "$WORLD/$m-clone" && printf '%s' "$input" | XDG_CONFIG_HOME="$WORLD/$m-config" ./potato 2>&1)
}

# remote_state: what another Player would see after pulling.
remote_state() {
  git clone -q "$WORLD/remote.git" "$WORLD/peek" && cat "$WORLD/peek"/game.txt 2>/dev/null
  rm -rf "$WORLD/peek"
}

FAILS=0
check() { # check DESC CONDITION-COMMAND...
  local desc="$1"; shift
  if "$@"; then echo "  ok   - $desc"; else echo "  FAIL - $desc"; FAILS=$((FAILS+1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
