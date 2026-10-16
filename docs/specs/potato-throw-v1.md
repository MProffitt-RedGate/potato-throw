<!-- Published as https://github.com/MProffitt-RedGate/potato-throw/issues/1 (label `ready-for-agent`). -->

# Potato Throw v1

## Problem Statement

A group of colleagues, each on their own WSL machine, want a lightweight bit of fun: a single Potato that gets thrown from person to person. It must not need everyone online at once. Each person should be able to launch it every now and then, see who holds the Potato, and, if it's them, Throw it at someone else. There should be no server to run, no accounts to set up, and almost nothing to install.

## Solution

A single bash script, `potato`, that lives in a shared git repository. Players clone the repo to install it. The state of the Game (Players, Holder, Throw history) is a line-based text file committed in the repo. Each launch pulls the latest state. Each Throw or Invite commits and pushes. The first launch on an empty Game makes you the First Player and Holder. Later Players Claim an invited Name on their first launch. The Holder sees "You have the potato!" and can Throw it at another Player. Everyone else sees who holds it and the last 5 Throws.

## User Stories

1. As the first person to launch the game, I want to be asked for a Name and become the First Player holding the Potato, so that the Game starts with no setup.
2. As a Player, I want to choose my own Name on first launch, so that others see something friendlier than my Linux username.
3. As a Player, I want my Name remembered locally after I join, so that I'm not asked again on later launches.
4. As a Player, I want to Invite someone by Name, so that they can join the Game.
5. As a Player, I want to be able to Invite whether or not I hold the Potato, so that I don't have to wait to bring friends in.
6. As a Player, I want an Invite to be rejected if the Name already exists (case-insensitive), so that Throws are never ambiguous.
7. As an invitee on a fresh clone, I want to see the list of invited-but-unclaimed Names and pick mine, so that I can join without typos.
8. As an invitee, I want my Claim to be permanent and recorded in the shared state, so that nobody else can take my Name.
9. As a Player, I want to see "You have the potato!" when I launch and hold it, so that I know it's my turn.
10. As the Holder, I want to choose another Player to Throw the Potato at, so that the game continues.
11. As the Holder, I want not to be able to Throw at myself, so that the Potato always moves.
12. As the Holder, I want to be able to Throw straight back to whoever threw it at me, so that two people can ping-pong it for fun.
13. As the Holder with no other Players, I want to be told to Invite someone first, so that I know why I can't Throw.
14. As a non-Holder, I want to see who currently holds the Potato, so that I can laugh at them.
15. As any Player, I want to see the last 5 Throws (who, to whom, when), so that I can follow the Potato's journey.
16. As a Player, I want a Throw to take effect for everyone on their next launch, so that the game works asynchronously.
17. As a Player, I want launching to pull the latest state automatically, so that I never see a stale Holder when I'm online.
18. As a Player, I want a rejected push on Throw to re-pull and recheck that I'm still the Holder, so that conflicting writes can't corrupt the game.
19. As a Player, I want one automatic retry when I'm still the Holder after a rejected push, so that a transient conflict doesn't make me redo my choice.
20. As a Player who is no longer the Holder after a re-pull, I want to be shown who holds the Potato now, so that I understand what happened.
21. As an offline Player, I want to see the last-known state with an "offline, may be out of date" warning, so that I still get something useful.
22. As an offline Player, I want Throw and Invite blocked, so that nobody ends up holding a Potato the others can't see.
23. As a new Player, I want to install the game by cloning the repo and running `./potato`, so that setup is trivial.
24. As a regular Player, I want `./potato install` to symlink the script onto my PATH, so that I can just type `potato`.
25. As a Player running via the symlink, I want the script to find its repository correctly, so that it works from any directory.
26. As a Player, I want my Name stored under my config directory rather than in the repo, so that my identity is per-machine and not committed.
27. As a repo maintainer, I want players to be repo collaborators, so that only invited people can push Throws.
28. As a maintainer, I want each Throw stored as a record (who, to whom, when), so that a message field can be added later without a migration.
29. As a maintainer, I want the state file in a plain line-based format with no `jq` dependency, so that the script stays tiny and git diffs are readable.
30. As a maintainer, I want the script to work on stock WSL with only bash and git, so that nothing extra needs installing.
31. As a Player, I want clear error messages when a pull or push fails for reasons other than offline (for example, no push access), so that I can tell what to fix.
32. As a Player, I want the Potato never to be lost or duplicated, so that exactly one Holder exists at all times.
33. As a Player, I want to quit from the menu at any time, so that a launch can be quick.
34. As a Player who made a typo in a menu choice, I want to be re-prompted rather than have the script crash, so that casual use is forgiving.

## Implementation Decisions

- The product is a single bash script with a small set of subcommands: the default interactive launch, and `install`.
- Terms follow `GLOSSARY.md`: Game, Player, Name, Potato, Holder, Throw, Invite, Claim, First Player, Throw history.
- Shared state lives in a text file in this git repo (see ADR 0001). Launch pulls; Throw and Invite commit and push.
- State is line-based with no `jq`. It records Players (a Name, and whether it has been Claimed), the current Holder, and the Throw records. Each Throw is its own record with who, to whom and when, so extra fields can be added later.
- Names are unique and compared case-insensitively. Inviting an existing Name is rejected.
- A Name is stored per machine in a config directory under `~/.config/potato-throw/`. The shared state records which Names are Claimed. A Claim is permanent.
- Empty state on first launch: ask for a Name, create the Game, make that Player the First Player and Holder. State with existing Players and no local Name: show the unclaimed invited Names and let the user pick one.
- Any Player can Invite at any time. An Invite adds a Name and sends no message.
- Throw rules: only the Holder can Throw. Self-throws are not allowed. Throwing back to the previous thrower is allowed. With one Player, the user is told to Invite someone first.
- Concurrency: on a rejected push, re-pull and recheck that the user is still the Holder. If so, retry once. If not, show the current Holder.
- Offline behaviour: if the pull fails because the remote is unreachable, show cached state with a warning and block Throw and Invite.
- Launch screens: the Holder sees "You have the potato!" with Throw, Invite and quit. Non-Holders see who has the Potato with Invite and quit. Both show the last 5 Throws.
- `./potato install` symlinks the script into `~/.local/bin`. The script resolves its repo through the symlink.
- Leaving the Game is out of scope. The Potato may get stuck with an inactive Player, and that is accepted.

## Testing Decisions

- A good test exercises only external behaviour: what `./potato` prints and returns for scripted input, and what another Player's clone sees after a pull. It does not test the state file's parser or any internal function.
- There is one seam: the `potato` command, run end-to-end as a black box.
- Each test builds a throwaway world: a local bare git repo as the shared remote, one clone and one config directory per simulated Player (via `HOME` or `XDG_CONFIG_HOME`), and scripted stdin.
- Cover: Game start, Claiming a Name, Invite rules including duplicates, Throw rules including self-throw and single-player, the Holder check, a rejected push with re-pull and retry, offline behaviour, launch screens with the last 5 Throws, and `install`.
- Tests are plain bash with no dependencies. We may move to bats-core later if they outgrow that.
- There are no existing tests in the repo, so there is no prior art.

## Out of Scope

- Leaving the Game or removing a Player.
- Messages attached to a Throw.
- Timers, explosions, scoring, leaderboards or any other mechanics.
- Live or real-time interaction and notifications.
- Sending Invites as actual messages.
- Any backend other than the git repo.
- Windows-native or macOS support. The target is WSL's bash.

## Further Notes

- The Potato can get stuck with an inactive Player. This is an accepted, funny failure mode.
- The message field is the obvious first expansion, which is why Throws are stored as records.
- See `GLOSSARY.md` and `docs/adr/0001-git-repo-as-shared-state.md`.
