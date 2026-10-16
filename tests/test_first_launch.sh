source "$(dirname "$0")/lib.sh"

new_world
join_machine alice

out=$(run_as alice $'Alice\nq\n')
check "asks for a Name"                    contains "$out" "Name"
check "Holder is told they have the potato" contains "$out" "You have the potato!"
check "state records Alice as Holder"       contains "$(remote_state)" "holder|Alice"
check "state records Alice as a Player"     contains "$(remote_state)" "player|Alice|claimed"

out2=$(run_as alice $'q\n')
check "second launch does not ask for a Name" bash -c '! [[ "$1" == *"Choose a Name"* ]]' _ "$out2"
check "second launch still shows the potato"  contains "$out2" "You have the potato!"

# Quitting at the Name prompt must not start a Game.
new_world
join_machine bob
out=$(run_as bob '')
check "EOF at the Name prompt starts no Game" bash -c '[[ -z "$1" ]]' _ "$(remote_state)"
check "EOF at the Name prompt shows no potato" bash -c '! [[ "$1" == *"potato!"* ]]' _ "$out"

# Invalid Names are re-prompted, and surrounding whitespace is trimmed.
new_world
join_machine carol
out=$(run_as carol $'   \nA|B\n  Carol  \nq\n')
check "invalid Names are re-prompted"  contains "$out" "can't be empty"
check "Name is trimmed in the state"   contains "$(remote_state)" "holder|Carol"$'\n'

exit $((FAILS>0))
