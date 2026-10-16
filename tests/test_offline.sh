source "$(dirname "$0")/lib.sh"

go_offline() { mv "$WORLD/remote.git" "$WORLD/remote.git.away"; }
go_online()  { mv "$WORLD/remote.git.away" "$WORLD/remote.git"; }

# Alice has thrown to Bob, so both have something to see; Carol is invited but has not joined.
new_world
join_machine alice; join_machine bob; join_machine carol
run_as alice $'Alice\ni\nBob\ni\nCarol\nq\n' >/dev/null
run_as bob $'1\nq\n' >/dev/null
run_as alice $'t\n1\nq\n' >/dev/null     # Alice -> Bob
run_as bob $'q\n' >/dev/null            # Bob launches once, so his cache knows he has the Potato

go_offline

# Cached state is shown, with a warning.
out=$(run_as bob $'q\n')
check "offline: warns the state may be out of date" contains "$out" "offline, may be out of date"
check "offline: the cached Holder is shown"        contains "$out" "You have the potato!"
check "offline: the cached Throw history is shown" contains "$out" "Alice -> Bob"

# Throw and Invite are blocked.
out=$(run_as bob $'t\ni\nq\n')
check "offline: Throw is not offered"              bash -c '! [[ "$1" == *"[t] throw"* ]]' _ "$out"
check "offline: Invite is not offered"             bash -c '! [[ "$1" == *"[i] invite"* ]]' _ "$out"
check "offline: trying to Throw is refused"        contains "$out" "can't Throw"
check "offline: trying to Invite is refused"       contains "$out" "can't Invite"

# A new user cannot join, or start a Game, while offline.
out=$(run_as carol $'1\nq\n')
check "offline: a new user is told to get online to join" contains "$out" "online"
check "offline: nothing is stored for the new user" bash -c '[[ ! -e "$1" ]]' _ "$WORLD/carol-config/potato-throw/name"

go_online
out=$(run_as bob $'q\n')
check "back online: no warning"                    bash -c '! [[ "$1" == *"out of date"* ]]' _ "$out"
check "back online: nothing changed while offline" bash -c '[[ "$1" == *"holder|Bob"* && "$1" != *"player|Zed"* ]]' _ "$(remote_state)"

# First launch with no state while offline must not start a Game that may already exist.
new_world
join_machine dan
go_offline
out=$(run_as dan $'Dan\nq\n')
check "offline first launch: does not ask for a Name" bash -c '! [[ "$1" == *"Choose a Name"* ]]' _ "$out"
check "offline first launch: explains why"         contains "$out" "can't tell"
go_online
check "offline first launch: no Game was started"  bash -c '[[ -z "$1" ]]' _ "$(remote_state)"

# A failure that is not "offline" is reported as such, still read-only, with the reason.
new_world
join_machine erin
run_as erin $'Erin\nq\n' >/dev/null
rewritten=$(git -C "$WORLD/remote.git" commit-tree 'main^{tree}' -m rewrite)
git -C "$WORLD/remote.git" update-ref refs/heads/main "$rewritten"   # history no longer fast-forwards
out=$(run_as erin $'t\nq\n')
check "other failure: says the update failed"      contains "$out" "Couldn't update"
check "other failure: is not called offline"       bash -c '! [[ "$1" == *"offline"* ]]' _ "$out"
check "other failure: still shows the cached state" contains "$out" "You have the potato!"
check "other failure: Throw is blocked"            bash -c '! [[ "$1" == *"[t] throw"* ]]' _ "$out"

# A push that is refused gives a clear message.
new_world
join_machine fay
run_as fay $'Fay\nq\n' >/dev/null
printf '#!/bin/sh\necho "no push access" >&2\nexit 1\n' > "$WORLD/remote.git/hooks/pre-receive"; chmod +x "$WORLD/remote.git/hooks/pre-receive"
out=$(run_as fay $'i\nGus\nq\n')
check "refused push: says to check push access"    contains "$out" "push access"
check "refused push: also points at the connection" contains "$out" "connection"
check "refused push: says nothing was changed"     contains "$out" "nothing was changed"

# First launch with no state and a failure that is not "offline": say what failed, not "get online".
new_world
join_machine hal
rewritten=$(git -C "$WORLD/remote.git" commit-tree 'main^{tree}' -m rewrite)
git -C "$WORLD/remote.git" update-ref refs/heads/main "$rewritten"
out=$(run_as hal $'Hal\nq\n')
check "first launch, other failure: says the update failed" contains "$out" "Couldn't update"
check "first launch, other failure: does not blame being offline" bash -c '! [[ "$1" == *"online"* ]]' _ "$out"
check "first launch, other failure: does not ask for a Name" bash -c '! [[ "$1" == *"Choose a Name"* ]]' _ "$out"

exit $((FAILS>0))
