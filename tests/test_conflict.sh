source "$(dirname "$0")/lib.sh"

# Alice holds the Potato; Bob is a Player; Alice also has a second machine.
setup() {
  new_world
  join_machine alice; join_machine bob
  run_as alice $'Alice\ni\nBob\nq\n' >/dev/null
  run_as bob $'1\nq\n' >/dev/null
}

# --- Throw: someone else pushes while Alice is choosing; she is still the Holder.
setup
session_start alice
session_wait_for "[q] quit"; session_send t
session_wait_for "Throw the potato at:"
run_as bob $'i\nZed\nq\n' >/dev/null          # Bob pushes in between
session_send 1
session_wait_for "You threw the potato to Bob"; threw=$?
session_send q
session_end; out=$SESSION_TEXT
check "a Throw survives a conflicting push (retried once)" bash -c '[[ $1 == 0 ]]' _ "$threw"
check "the Throw took effect"                contains "$(remote_state)" "holder|Bob"
check "the other Player's Invite was not lost" contains "$(remote_state)" "player|Zed|unclaimed"
check "exactly one Holder"                   bash -c '[[ "$(grep -c "^holder|" <<<"$1")" == 1 ]]' _ "$(remote_state)"
check "exactly one Throw record"             bash -c '[[ "$(grep -c "^throw|" <<<"$1")" == 1 ]]' _ "$(remote_state)"

# --- Throw: Alice's other machine Throws first, so she is no longer the Holder.
setup
join_machine alice2
mkdir -p "$WORLD/alice2-config/potato-throw"; cp "$WORLD/alice-config/potato-throw/name" "$WORLD/alice2-config/potato-throw/name"
session_start alice
session_wait_for "[q] quit"; session_send t
session_wait_for "Throw the potato at:"
# Alice's other machine Throws to Bob. A distinct commit date matters: two identical
# commits (same parent, content and second) would hash the same and never conflict.
GIT_AUTHOR_DATE=2020-01-01T00:00:00Z GIT_COMMITTER_DATE=2020-01-01T00:00:00Z run_as alice2 $'t\n1\nq\n' >/dev/null
session_send 1
session_wait_for "Too late: Bob has the potato now."; seen=$?
session_send q
session_end; out=$SESSION_TEXT
check "the loser is shown who holds the Potato now" bash -c '[[ $1 == 0 ]]' _ "$seen"
check "the loser's screen then shows Bob as the Holder" contains "$out" $'Too late: Bob has the potato now.\nBob has the potato.'
check "the loser is not told the Throw worked" bash -c '! [[ "$1" == *"You threw"* ]]' _ "$out"
check "the Potato is not duplicated or lost" bash -c '[[ "$(grep -c "^holder|Bob" <<<"$1")" == 1 && "$(grep -c "^holder|" <<<"$1")" == 1 ]]' _ "$(remote_state)"
check "only the winning Throw is recorded"   bash -c '[[ "$(grep -c "^throw|" <<<"$1")" == 1 ]]' _ "$(remote_state)"

# --- Invite: someone else pushes while Alice is typing; the Name is still free.
setup
session_start alice
session_wait_for "[q] quit"; session_send i
session_wait_for "Name to invite:"
run_as bob $'i\nYan\nq\n' >/dev/null
session_send Zed
session_wait_for "Invited Zed"; invited=$?
session_send q
session_end; out=$SESSION_TEXT
check "an Invite survives a conflicting push (retried once)" bash -c '[[ $1 == 0 ]]' _ "$invited"
check "both Invites are in the state"        bash -c '[[ "$1" == *"player|Yan|unclaimed"* && "$1" == *"player|Zed|unclaimed"* ]]' _ "$(remote_state)"

# --- Invite: the same Name was invited meanwhile.
setup
session_start alice
session_wait_for "[q] quit"; session_send i
session_wait_for "Name to invite:"
run_as bob $'i\nzed\nq\n' >/dev/null
session_send Zed
session_wait_for "already a Player"; dup=$?
session_send q
session_end; out=$SESSION_TEXT
check "a Name invited meanwhile is reported as taken" bash -c '[[ $1 == 0 ]]' _ "$dup"
check "the Name is recorded once"            bash -c '[[ "$(grep -ci "^player|zed|" <<<"$1")" == 1 ]]' _ "$(remote_state)"

exit $((FAILS>0))
