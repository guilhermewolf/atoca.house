---
name: atoca-gitops
description: The git, branch and pull-request procedure for the guilhermewolf/atoca.house GitOps repo. Use for any change to the homelab repo — adding or editing an app, infra, Talos or Terraform files — and for keeping the local checkout in sync, rebasing a branch on main, opening or updating a PR, and checking PR/CI status.
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    category: devops
    tags: [git, github, gitops, kubernetes, argocd, atoca]
    requires_toolsets: [terminal]
---

# atoca.house — GitOps change procedure

## When to Use

Any time you touch `guilhermewolf/atoca.house`: adding or changing an app,
editing infra, answering "what is deployed", or opening/updating a PR.

## Ground truth

| Thing | Value |
| --- | --- |
| Checkout | `/opt/data/workspace/atoca.house` |
| Remote | `origin` → `https://github.com/guilhermewolf/atoca.house.git` |
| Trunk | `main` — protected by convention: never commit, never push to it |
| Deploy | ArgoCD applies `main` to the live cluster. A merged PR is a deploy. |
| Conventions | `CLAUDE.md` at the repo root — read it before editing files |
| Auth | pushes are already authenticated by the helper in `/opt/data/.gitconfig` — nothing to configure |

`kubectl` (at `/opt/data/bin/kubectl`) is read-only in this environment: use it
to inspect the cluster, never to apply, patch, delete or scale. Deployment is
ArgoCD's job after a human merges.

## Procedure

### 1. Sync before anything else

```sh
cd /opt/data/workspace/atoca.house
git switch main
git fetch origin --prune
git reset --hard origin/main
```

If `git status` is dirty and the work is not yours to discard, stash it
(`git stash push -u -m "<why>"`) and say so rather than throwing it away.

### 2. Branch

```sh
git switch -c <type>/<short-topic> origin/main
```

`<type>` is one of `feat`, `fix`, `chore`, `refactor`, `docs`. One topic per
branch. Branch off `origin/main`, never off another feature branch.

### 3. Change

Follow `CLAUDE.md`. In short, for an app under `apps/<category>/<app>/` or
`infra/k8s/<category>/<app>/`:

- `app-config.yaml` (discovery) and `values.yaml` (bjw-s `app-template`) are
  required; `secrets.yaml`, `backup.yaml`, `scaleobject.yaml` when applicable.
- Copy the shape from the closest existing app in the same category rather than
  inventing one.
- Pin images with a digest and keep the `# renovate:` comment above the tag.
- Keep the repo-wide security defaults, storage classes, HTTPRoute gateways and
  `*.atoca.house` hostnames.
- Do not touch ApplicationSets or `argocd/applications/root.yaml`, and do not
  hand-edit chart versions Renovate owns.

Check your work before committing:

```sh
git diff
python3 -c 'import sys,yaml;[yaml.safe_load_all(open(f)) and None for f in sys.argv[1:]]' $(git diff --name-only --diff-filter=d origin/main -- '*.yaml')
```

### 4. Commit

Conventional Commits, imperative subject under ~72 chars, body only when the
"why" is not obvious from the diff:

```sh
git add -A -- <paths you actually changed>
git commit -m "feat(media): add <app> with volsync backup"
```

Stage paths explicitly. Never `git add -A` from the repo root without a path
filter when the tree has unrelated modifications.

### 5. Rebase on main, always

Immediately before pushing — and again any time the PR falls behind:

```sh
git fetch origin
git rebase origin/main
```

On conflict: resolve it in the files, `git add <file>`, `git rebase
--continue`. If a conflict is not yours to resolve confidently, run `git rebase
--abort`, leave the branch as it was, and report what conflicted with whom.
Never resolve a conflict by discarding someone else's hunk.

After a rebase of an already-pushed branch:

```sh
git push --force-with-lease origin HEAD
```

First push of a new branch:

```sh
git push -u origin HEAD
```

Plain `git push --force`, `git push -f` and any push to `main` are blocked.

### 6. Open the PR

Use the GitHub MCP tools (`create_pull_request`), base `main`, head your
branch. The PR body states:

- **What** changed, file by file, in one line each.
- **Why** — the request or the problem.
- **Cluster impact** — what ArgoCD will do on merge: new Application, rollout
  and restart, PVC creation, downtime, dependency on the NAS being online.
- **Verification** — what you checked, and what a human still has to check.

Draft the PR if anything is unverified, and say what.

### 7. Follow through

- `get_pull_request_status` for CI. If a check fails, fix it on the same branch
  and push again — do not open a second PR.
- `update_pull_request_branch`, or a local rebase + `--force-with-lease`, when
  the PR falls behind `main`.
- Report the PR URL back to the user. Do not merge — humans merge.

## Pitfalls

- **Stale start.** Branching off a local `main` that has not been fetched
  produces a PR full of phantom conflicts. Step 1 is not optional.
- **Merge instead of rebase.** This repo's branches are rebased onto `main`;
  do not `git merge main` into a feature branch.
- **Working on `main` by accident.** Check `git rev-parse --abbrev-ref HEAD`
  before your first commit. If you already committed on `main`: create the
  branch at the current commit, then reset `main` back to `origin/main`.
- **Two write paths.** Change files through this checkout only. The GitHub MCP
  server is for PRs, issues and reads — not for writing file content.
- **Values that must stay private.** They belong in a 1Password item referenced
  by an ExternalSecret, never as literal text in the tree.
- **Deleted branch after merge.** The pod's start-up sync prunes local branches
  whose upstream is gone; do not reuse an old branch, cut a fresh one.

## Verification

Before saying you are done:

```sh
git status                      # clean tree
git log --oneline origin/main..HEAD   # only your commits
git diff origin/main --stat     # only files you meant to touch
```

Plus: the PR exists, its base is `main`, CI is green or its failure is
explained, and the user has the URL.
