# Shared state lives in the git repo

The Game's state (Players, Holder, Throw history) is a file committed to this repository. Each launch pulls; each Throw or Invite commits and pushes. Players are repo collaborators.

## Considered options

- **GitHub Issue or Gist via `gh`**: no repo writes, but adds a `gh` dependency and auth setup for every Player.
- **Hosted backend**: cleanest for concurrency, but a server to build, host and keep running for a joke game.

## Why git

Players already have to clone the repo to install the game, so git adds no new dependency. Throw history comes for free. A single bash script can drive it.

## Consequences

- Every Player needs push access to the repo.
- Concurrent writes can be rejected; on a rejected push, re-pull, recheck that you're still the Holder, and retry once.
- Moving to another backend later means changing how the script reads and writes state.
