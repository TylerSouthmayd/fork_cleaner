# Fork Cleaner

CLI tool to delete your old forks.

Fetches your forked GitHub repositories with no open pull requests, then prompts for their individual deletion.


## Env vars

- `GITHUB_ACCESS_TOKEN`: required
  - PAT with repo scope
- `GITHUB_HOST`: optional
  - default: `https://api.github.com`
  - override for enterprise users (e.g. `https://api.github.company.com`)

## Usage

```sh
# install deps
mix deps.get

# run dev
GITHUB_ACCESS_TOKEN=$GITHUB_ACCESS_TOKEN GITHUB_HOST=$GITHUB_HOST iex -S mix

# build prod
MIX_ENV=prod mix escript.build

# run prod
./fork_cleaner
```
