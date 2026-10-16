source "$(dirname "$0")/lib.sh"

arrows() { grep -c -- '->' <<<"$1"; }

new_world
join_machine alice; join_machine bob; join_machine carol
run_as alice $'Alice\ni\nBob\ni\nCarol\nq\n' >/dev/null
run_as bob $'1\nq\n' >/dev/null
run_as carol $'1\nq\n' >/dev/null

# No Throws yet: nothing broken, on both kinds of screen.
out=$(run_as alice $'q\n')
check "no Throws: the Holder screen says so"      contains "$out" "No Throws yet"
check "no Throws: no Throw lines"                 bash -c '[[ "$(grep -c -- "->" <<<"$1")" == 0 ]]' _ "$out"
out=$(run_as bob $'q\n')
check "no Throws: the non-Holder screen says so"  contains "$out" "No Throws yet"

# Two Throws: only those two are shown.
run_as alice $'t\n1\nq\n' >/dev/null    # Alice -> Bob
run_as bob   $'t\n2\nq\n' >/dev/null    # Bob -> Carol
out=$(run_as carol $'q\n')
check "fewer than 5: shows both Throws"           bash -c '[[ "$(grep -c -- "->" <<<"$1")" == 2 ]]' _ "$out"
check "a Throw shows who, to whom"                contains "$out" "Bob -> Carol"

# Seven Throws: only the last 5, newest first.
run_as carol $'t\n1\nq\n' >/dev/null    # Carol -> Alice
run_as alice $'t\n2\nq\n' >/dev/null    # Alice -> Carol
run_as carol $'t\n2\nq\n' >/dev/null    # Carol -> Bob
run_as bob   $'t\n1\nq\n' >/dev/null    # Bob -> Alice
run_as alice $'t\n1\nq\n' >/dev/null    # Alice -> Bob
out=$(run_as bob $'q\n')                # Bob is the Holder
check "the Holder screen shows exactly 5 Throws"  bash -c '[[ "$(grep -c -- "->" <<<"$1")" == 5 ]]' _ "$out"
check "the oldest Throws are dropped"             bash -c '! [[ "$1" == *"Bob -> Carol"* ]]' _ "$out"
check "the newest Throw is listed first"          bash -c '[[ "$(grep -- "->" <<<"$1" | head -1)" == *"Alice -> Bob"* ]]' _ "$out"
check "each Throw shows when"                     bash -c '[[ "$1" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z ]]' _ "$out"
out=$(run_as carol $'q\n')
check "the non-Holder screen shows exactly 5 Throws" bash -c '[[ "$(grep -c -- "->" <<<"$1")" == 5 ]]' _ "$out"
check "the 5th-newest Throw is still shown"       contains "$out" "Carol -> Alice"

# The history refreshes after a Throw in the same session.
new_world
join_machine dan; join_machine eve
run_as dan $'Dan\ni\nEve\nq\n' >/dev/null
run_as eve $'1\nq\n' >/dev/null
out=$(run_as dan $'t\n1\nq\n')
after=${out#*threw the potato}
check "the history updates right after a Throw"   contains "$after" "Dan -> Eve"

exit $((FAILS>0))
