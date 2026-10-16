source "$(dirname "$0")/lib.sh"

new_world
join_machine alice
run_as alice $'Alice\ni\nBob\ni\nCarol\nq\n' >/dev/null

# A new user on a fresh clone sees the unclaimed Names and picks one.
join_machine bob
out=$(run_as bob $'1\nq\n')
check "unclaimed Names are listed"          contains "$out" "Bob"
check "the other unclaimed Name is listed"  contains "$out" "Carol"
check "the First Player is not offered (already Claimed)" bash -c '! [[ "$1" == *") Alice"* ]]' _ "$out"
check "the Claim is recorded in the shared state" contains "$(remote_state)" "player|Bob|claimed"
check "Carol is still unclaimed"            contains "$(remote_state)" "player|Carol|unclaimed"
check "the new Player sees who has the Potato" contains "$out" "Alice has the potato."
check "the new Player is offered Invite"    contains "$out" "invite"

# The Name is stored locally: the next launch does not ask again.
out=$(run_as bob $'q\n')
check "second launch does not offer a Claim" bash -c '! [[ "$1" == *"Claim"* ]]' _ "$out"
check "second launch shows who has the Potato" contains "$out" "Alice has the potato."

# A Claimed Name no longer appears for other new users.
join_machine carol
out=$(run_as carol $'1\nq\n')
check "Claimed Bob is not listed for Carol" bash -c '! [[ "$1" == *"Bob"* ]]' _ "$out"
check "Carol Claims Carol"                  contains "$(remote_state)" "player|Carol|claimed"

# A non-Holder can Invite.
out=$(run_as bob $'i\nDave\nq\n')
check "a non-Holder can Invite"             contains "$out" "Invited Dave"
check "Dave is recorded as unclaimed"       contains "$(remote_state)" "player|Dave|unclaimed"
check "Alice is still the Holder"           contains "$(remote_state)" "holder|Alice"

# Bad menu choices are re-prompted; quitting claims nothing.
join_machine dave
out=$(run_as dave $'9\nx\n1\nq\n')
check "an out-of-range choice is re-prompted" contains "$out" "Please choose"
check "Dave Claims Dave after re-prompt"    contains "$(remote_state)" "player|Dave|claimed"

new_world
join_machine erin; join_machine frank
run_as erin $'Erin\nq\n' >/dev/null
out=$(run_as frank '')
check "EOF at the Claim prompt claims nothing" bash -c '[[ "$(grep -c "|claimed" <<<"$1")" == 1 ]]' _ "$(remote_state)"
out=$(run_as frank $'q\n')
check "with nothing to Claim, the user is told to ask for an Invite" contains "$out" "Invite"
check "no Name is stored when nothing was Claimed" bash -c '[[ ! -e "$1" ]]' _ "$WORLD/frank-config/potato-throw/name"

# A rejected push on Claim leaves no Name behind, and the Claim can be retried.
new_world
join_machine gina; join_machine hank
run_as gina $'Gina\ni\nHank\nq\n' >/dev/null
hook="$WORLD/remote.git/hooks/pre-receive"
printf '#!/bin/sh\nexit 1\n' > "$hook"; chmod +x "$hook"
out=$(run_as hank $'1\nq\n')
check "failed Claim is reported" contains "$out" "Couldn't publish the Claim"
check "failed Claim stores no Name" bash -c '[[ ! -e "$1" ]]' _ "$WORLD/hank-config/potato-throw/name"
rm "$hook"
out=$(run_as hank $'1\nq\n')
check "the Claim works once the remote accepts pushes" contains "$(remote_state)" "player|Hank|claimed"

# Leading zeros are decimal, never octal.
new_world
join_machine ivy; join_machine jack
run_as ivy $'Ivy\ni\nJack\ni\nKate\nq\n' >/dev/null
out=$(run_as jack $'08\n09\n01\nq\n')
check "08 is just an out-of-range number" contains "$out" "Please choose"
check "no arithmetic error leaks out" bash -c '! [[ "$1" == *"too great"* ]]' _ "$out"
check "01 picks the first Name" contains "$(remote_state)" "player|Jack|claimed"

exit $((FAILS>0))
