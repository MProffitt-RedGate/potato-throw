source "$(dirname "$0")/lib.sh"

new_world
join_machine alice
H="$WORLD/alice-home"; mkdir -p "$H" "$WORLD/elsewhere"
link="$H/.local/bin/potato"

# install: HOME is the only thing we point at the sandbox; XDG_CONFIG_HOME stays unset.
as_alice() { # as_alice DIR INPUT CMD...
  local dir="$1" input="$2"; shift 2
  (cd "$dir" && printf '%s' "$input" | env -u XDG_CONFIG_HOME HOME="$H" "$@" 2>&1)
}

out=$(as_alice "$WORLD/alice-clone" '' ./potato install); rc=$?
check "install succeeds"                          bash -c '[[ $1 == 0 ]]' _ "$rc"
check "install makes ~/.local/bin/potato a symlink" test -L "$link"
check "the symlink points at the cloned script"   bash -c '[[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]' _ "$link" "$WORLD/alice-clone/potato"
check "install says where it linked"              contains "$out" ".local/bin/potato"
check "install hints at PATH when needed"         contains "$out" "PATH"

# Running through the symlink from any directory finds the repository and works.
out=$(as_alice "$WORLD/elsewhere" $'Alice\nq\n' "$link")
check "launch via the symlink asks for a Name"    contains "$out" "Choose a Name"
check "launch via the symlink starts the Game in the clone's repo" contains "$(remote_state)" "holder|Alice"
check "the Name is stored under ~/.config/potato-throw" test -f "$H/.config/potato-throw/name"
out=$(as_alice "$WORLD/elsewhere" $'q\n' "$link")
check "a second launch via the symlink remembers the Name" contains "$out" "You have the potato!"
check "no state file was written into the working directory" bash -c '[[ ! -e "$1/game.txt" ]]' _ "$WORLD/elsewhere"

# Installing again is harmless.
out=$(as_alice "$WORLD/alice-clone" '' ./potato install); rc=$?
check "a second install succeeds"                 bash -c '[[ $1 == 0 ]]' _ "$rc"
check "a repeat install says it was already installed" contains "$out" "Already installed"
check "the symlink is unchanged"                  bash -c '[[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]' _ "$link" "$WORLD/alice-clone/potato"
out=$(as_alice "$WORLD/elsewhere" '' "$link" install); rc=$?
check "install via the symlink succeeds too"      bash -c '[[ $1 == 0 ]]' _ "$rc"

# A stale link (clone deleted) or a link to another clone of the game is re-pointed.
rm -f "$link"; ln -s "$WORLD/gone/potato" "$link"
out=$(as_alice "$WORLD/alice-clone" '' ./potato install); rc=$?
check "a dangling link is re-pointed"             bash -c '[[ $1 == 0 && "$(readlink -f "$2")" == "$(readlink -f "$3")" ]]' _ "$rc" "$link" "$WORLD/alice-clone/potato"
git clone -q "$WORLD/remote.git" "$WORLD/second-clone"
rm -f "$link"; ln -s "$WORLD/second-clone/potato" "$link"
out=$(as_alice "$WORLD/alice-clone" '' ./potato install); rc=$?
check "a link to another clone is re-pointed"     bash -c '[[ $1 == 0 && "$(readlink -f "$2")" == "$(readlink -f "$3")" ]]' _ "$rc" "$link" "$WORLD/alice-clone/potato"

# A different file already there is never overwritten.
mkdir -p "$H/.local/bin"; rm -f "$link"; echo "mine" > "$link"
out=$(as_alice "$WORLD/alice-clone" '' ./potato install); rc=$?
check "install refuses to overwrite another file" bash -c '[[ $1 != 0 ]]' _ "$rc"
check "the other file is left alone"              bash -c '[[ "$(cat "$1")" == mine ]]' _ "$link"
check "install explains why"                      contains "$out" "already exists"

# No PATH hint when it is already on PATH.
rm -f "$link"
out=$(as_alice "$WORLD/alice-clone" '' env PATH="$H/.local/bin:$PATH" ./potato install)
check "no PATH hint when ~/.local/bin is on PATH" bash -c '! [[ "$1" == *"PATH"* ]]' _ "$out"

# Unknown subcommands are an error, not a silent launch.
out=$(as_alice "$WORLD/alice-clone" 'q' ./potato frobnicate); rc=$?
check "an unknown subcommand fails with usage"    bash -c '[[ $1 != 0 && "$2" == *"Usage"* ]]' _ "$rc" "$out"

exit $((FAILS>0))
