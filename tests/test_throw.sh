source "$(dirname "$0")/lib.sh"

# Only one Player: told to Invite someone first.
new_world
join_machine alice
run_as alice $'Alice\nq\n' >/dev/null
out=$(run_as alice $'t\nq\n')
check "a lone Holder is told to Invite someone first" contains "$out" "Invite someone first"
check "nothing was thrown"                  contains "$(remote_state)" "holder|Alice"

# Alice Invites Bob, who joins.
run_as alice $'i\nBob\nq\n' >/dev/null
join_machine bob
run_as bob $'1\nq\n' >/dev/null

# The Holder Throws at another Player.
out=$(run_as alice $'t\n1\nq\n')
check "the Throw list offers Bob"           contains "$out" "1) Bob"
check "the Throw list does not offer yourself" bash -c '! [[ "$1" == *") Alice"* ]]' _ "$out"
check "the Throw is confirmed"              contains "$out" "You threw the potato to Bob"
check "the Holder is now Bob"               contains "$(remote_state)" "holder|Bob"
check "the Throw is stored as a record (who, to whom, when)" bash -c '[[ "$1" =~ (^|$'"'"'\n'"'"')throw\|Alice\|Bob\|[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z ]]' _ "$(remote_state)"
check "the Thrower now sees Bob has it"     contains "$out" "Bob has the potato."

# The recipient sees it on their next launch.
out=$(run_as bob $'q\n')
check "the recipient sees they have the potato" contains "$out" "You have the potato!"

# Only the Holder can Throw.
out=$(run_as alice $'t\nq\n')
check "a non-Holder is not offered Throw"   bash -c '! [[ "$1" == *"[t] throw"* ]]' _ "$out"
check "a non-Holder who tries is refused"   contains "$out" "Only the Holder can Throw"
check "the Holder is unchanged"             contains "$(remote_state)" "holder|Bob"

# Throwing straight back is allowed.
out=$(run_as bob $'t\n1\nq\n')
check "Bob can Throw straight back to Alice" contains "$out" "You threw the potato to Alice"
check "Alice is the Holder again"           contains "$(remote_state)" "holder|Alice"

# An invited-but-unclaimed Player can be Thrown to, and finds out when they join.
run_as alice $'i\nCarol\nt\n2\nq\n' >/dev/null
check "the Potato can go to an unclaimed Player" contains "$(remote_state)" "holder|Carol"
join_machine carol
out=$(run_as carol $'1\nq\n')
check "the recipient sees it right after Claiming" contains "$out" "You have the potato!"

# Bad choices are re-prompted. Carol's list is 1) Alice 2) Bob.
out=$(run_as carol $'t\n0\nx\n9\n1\nq\n')
check "bad Throw choices are re-prompted"   contains "$out" "Please choose"
check "a valid choice then goes through"    contains "$(remote_state)" "holder|Alice"

# Quitting at the Throw prompt throws nothing.
run_as alice $'t\n' >/dev/null
check "EOF at the Throw prompt throws nothing" contains "$(remote_state)" "holder|Alice"

# A rejected push leaves the Potato where it was, and the Throw can be retried.
hook="$WORLD/remote.git/hooks/pre-receive"
printf '#!/bin/sh\nexit 1\n' > "$hook"; chmod +x "$hook"
out=$(run_as alice $'t\n1\nq\n')
check "a failed Throw is reported"          contains "$out" "Couldn't publish the Throw"
check "a failed Throw is not claimed as success" bash -c '! [[ "$1" == *"You threw"* ]]' _ "$out"
rm "$hook"
out=$(run_as alice $'t\n1\nq\n')
check "the Throw works once the remote accepts pushes" contains "$out" "You threw the potato to Bob"
check "Bob is the Holder after the retry"   contains "$(remote_state)" "holder|Bob"

# A huge number must not wrap around into a valid choice (2^64 + 1 wraps to 1). Bob is the Holder.
run_as bob $'t\n18446744073709551617\nq\n' >/dev/null
check "a huge number is rejected, not wrapped" contains "$(remote_state)" "holder|Bob"

exit $((FAILS>0))
