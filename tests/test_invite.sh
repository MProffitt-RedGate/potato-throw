source "$(dirname "$0")/lib.sh"

new_world
join_machine alice
run_as alice $'Alice\nq\n' >/dev/null

out=$(run_as alice $'i\nBob\nq\n')
check "Invite is confirmed"                 contains "$out" "Invited Bob"
check "state records Bob as unclaimed"      contains "$(remote_state)" "player|Bob|unclaimed"
check "Alice is still the Holder"           contains "$(remote_state)" "holder|Alice"

out=$(run_as alice $'i\nbOB\nq\n')
check "duplicate Name (any case) is rejected" contains "$out" "already"
check "duplicate is not recorded" bash -c '[[ "$(grep -ci "^player|bob|" <<<"$1")" == 1 ]]' _ "$(remote_state)"

out=$(run_as alice $'i\nALICE\nq\n')
check "inviting yourself is rejected as a duplicate" contains "$out" "already"

out=$(run_as alice $'i\n\nA|B\nCarol\nq\n')
check "invalid Names are re-prompted" contains "$out" "can't be empty"
check "state records Carol as unclaimed" contains "$(remote_state)" "player|Carol|unclaimed"

run_as alice $'i\nA.B\nq\n' >/dev/null
out=$(run_as alice $'i\nAxB\nq\n')
check "Names with regex characters are matched literally" contains "$out" "Invited AxB"

# A rejected push must leave nothing half-published locally.
new_world
join_machine dave
run_as dave $'Dave\nq\n' >/dev/null
hook="$WORLD/remote.git/hooks/pre-receive"
printf '#!/bin/sh\nexit 1\n' > "$hook"; chmod +x "$hook"
out=$(run_as dave $'i\nEve\nq\n')
check "failed push reports the Invite was not published" contains "$out" "Couldn't publish"
check "failed push is not claimed as success" bash -c '! [[ "$1" == *"Invited Eve"* ]]' _ "$out"
rm "$hook"
out=$(run_as dave $'i\nEve\nq\n')
check "the same Invite works once the remote accepts pushes" contains "$out" "Invited Eve"
check "state records Eve after the retry" contains "$(remote_state)" "player|Eve|unclaimed"
check "the Game start was not lost" contains "$(remote_state)" "holder|Dave"

# Backslashes in Names are matched literally.
run_as dave $'i\nA\\tB\nq\n' >/dev/null
out=$(run_as dave $'i\nA\\tB\nq\n')
check "backslash Names are detected as duplicates" contains "$out" "already"

exit $((FAILS>0))
