# Potato Throw

A tiny asynchronous game of hot potato for the terminal. There is one Potato and one Holder at a time. Launch the game now and then to see who has it. If it's you, Throw it at someone else.

Nobody has to be online at the same time, and there is no server. The state of the Game lives in a text file in this git repository.

## Install

You need WSL (or any Linux shell) with `bash`, `git` and `awk`, and push access to this repository.

```bash
git clone git@github.com:MProffitt-RedGate/potato-throw.git
cd potato-throw
./potato
```

That's all you need. To run it from any directory, link it onto your PATH:

```bash
./potato install
```

This creates `~/.local/bin/potato`. If `~/.local/bin` isn't on your PATH, the command tells you what to add to your shell profile. After that, just type `potato`.

Install is safe to repeat. It never overwrites a different file, and it re-points the link if you re-cloned the repository.

## How to play

### Joining

- **Starting a new Game:** if no Game exists yet, the first launch asks you to choose a Name. You become the First Player and the Holder.
- **Joining an existing Game:** another Player has to Invite you first. When you launch, you see the invited Names nobody has Claimed yet. Pick yours by number. Your Claim is permanent and recorded in the shared state, so nobody else can take your Name.

Your Name is stored on your machine under `~/.config/potato-throw/`, so you aren't asked again. It is not committed to the repository.

### The menu

Every launch pulls the latest state, then shows who has the Potato and the last 5 Throws (who, to whom, when).

| Key | When | What it does |
| --- | --- | --- |
| `t` | You hold the Potato | Throw it: pick another Player by number. |
| `i` | Any time | Invite someone: type the Name you want to add. |
| `q` | Any time | Quit. |

If you are the Holder, you see **You have the potato!**. Everyone else sees who has it.

### Rules

- Only the Holder can Throw.
- You can't Throw at yourself. Throwing straight back to whoever threw it at you is fine.
- You can Throw to someone who has been invited but hasn't joined yet. They find out when they join.
- With no one else in the Game, you're told to Invite someone first.
- Any Player can Invite at any time, whether or not they hold the Potato.
- Names are unique and case-insensitive. A Name can't be empty or contain `|`.
- An Invite sends no message. Tell your friend yourself, then they clone the repo and Claim their Name.
- There's no way to leave the Game. If the Potato lands with someone who never launches it again, it stays there. That's part of the fun.

### Offline and conflicts

- **Offline:** if the shared repository can't be reached, you see the last-known state with an "offline, may be out of date" warning. Throw, Invite and joining are blocked until you're back online.
- **Other update failures:** if the update fails for another reason, such as a refused login or a rewritten history, the game says what failed and stays read-only.
- **Simultaneous writes:** if two people write at once, the loser's game re-pulls and checks again. If you're still the Holder, or the Name is still free, it retries once. Otherwise it tells you who has the Potato now.
- **Refused pushes:** if a push is refused, for example you don't have push access, nothing is changed and you're told to check your connection and access.

## How it works

The whole game is one bash script, `potato`. The state is a plain line-based file, `game.txt`, committed in this repository:

```
holder|Alice
player|Alice|claimed
player|Bob|unclaimed
throw|Alice|Bob|2026-10-16T09:55:25Z
```

Launching pulls. Inviting, Claiming and Throwing commit and push. Each Throw is its own record (who, to whom, when), so extra fields can be added later. See [`GLOSSARY.md`](GLOSSARY.md) for the terms and [`docs/adr/0001-git-repo-as-shared-state.md`](docs/adr/0001-git-repo-as-shared-state.md) for why git is the shared state.

## Tests

The tests are plain bash with no dependencies. Each one builds a throwaway world, with a bare git repo as the remote and a clone and config directory per simulated Player, and drives only the `./potato` command.

```bash
bash tests/run.sh                 # everything
bash tests/test_throw.sh          # one file
```

## More

- The spec is in [`docs/specs/potato-throw-v1.md`](docs/specs/potato-throw-v1.md).
- Work is tracked in [GitHub Issues](https://github.com/MProffitt-RedGate/potato-throw/issues).
