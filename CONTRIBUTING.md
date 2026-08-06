# Contributing to TradeX

Welcome to the project! This doc walks you through the full workflow — from forking the repo to getting your changes merged. Follow it step by step and we'll stay in sync with no confusion.

> Wherever you see `YOUR_USERNAME` below, swap in your own GitHub username.

---

## 1. Fork the Repository

1. Go to the main repo: `https://github.com/NK2552003/TradeX`
2. Click **Fork** (top right) — this creates a copy under your own GitHub account:
   `https://github.com/YOUR_USERNAME/TradeX`

You'll always push your work to **your fork**, never directly to the original repo.

---

## 2. Clone Your Fork Locally

```bash
git clone https://github.com/YOUR_USERNAME/TradeX.git
cd TradeX
```

---

## 3. Set Up Remotes (origin + upstream)

By default, `origin` points to your fork. We now add the original repo as `upstream` so you can pull in the latest changes.

```bash
git remote add upstream https://github.com/NK2552003/TradeX.git
```

Verify both remotes are set correctly:

```bash
git remote -v
```

You should see something like:

```
origin    https://github.com/YOUR_USERNAME/TradeX.git (fetch)
origin    https://github.com/YOUR_USERNAME/TradeX.git (push)
upstream  https://github.com/NK2552003/TradeX.git (fetch)
upstream  https://github.com/NK2552003/TradeX.git (push)
```

---

## 4. Keep Your Fork in Sync

**Before starting any new work**, always sync with upstream first so you're not building on outdated code.

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

Do this every time before creating a new branch.

---

## 5. Create a New Branch for Every Task

Never work directly on `main`. Create a fresh branch per feature/fix/task.

```bash
git checkout -b type/short-description
```

### Branch naming convention

| Prefix      | Use case                          | Example                      |
|-------------|------------------------------------|-------------------------------|
| `feature/`  | New feature                        | `feature/user-auth`          |
| `fix/`      | Bug fix                            | `fix/login-crash`            |
| `chore/`    | Config, deps, cleanup              | `chore/update-deps`          |
| `docs/`     | Documentation only                 | `docs/api-readme`            |
| `refactor/` | Code restructure, no behavior change | `refactor/api-routes`      |

Example:

```bash
git checkout -b feature/payment-integration
```

---

## 6. Make Your Changes

- Keep each branch focused on **one task/feature**. Don't mix unrelated changes.
- Commit often, in small logical chunks — not one giant commit at the end.
- Test locally before committing.

### Commit message format

```
type: short summary (max ~50 chars)

Optional longer description if needed — what changed and why.
```

Examples:

```bash
git add .
git commit -m "feat: add Razorpay payment gateway integration"
git commit -m "fix: resolve null pointer on empty cart checkout"
git commit -m "docs: update setup instructions in README"
```

Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## 7. Push Your Branch to Your Fork

```bash
git push origin feature/payment-integration
```

If you add more commits later on the same branch, just push again:

```bash
git push origin feature/payment-integration
```

---

## 8. Open a Pull Request (PR)

1. Go to your fork on GitHub — you'll see a **"Compare & pull request"** prompt.
2. Set:
   - **Base repository:** `NK2552003/TradeX` → base branch: `main`
   - **Head repository:** `YOUR_USERNAME/TradeX` → compare branch: `feature/payment-integration`
3. Fill in the PR:
   - **Title:** clear and short (e.g. "Add Razorpay payment integration")
   - **Description:** what you did, why, and how to test it. Link related issues (e.g. `Closes #12`).
4. Submit the PR.

I'll review it, may leave comments, and merge once it's good.

---

## 9. If Changes Are Requested

1. Make edits locally on the **same branch**.
2. Commit and push again — the PR updates automatically:

```bash
git add .
git commit -m "fix: address review comments"
git push origin feature/payment-integration
```

No need to open a new PR.

---

## 10. After Your PR Is Merged

1. Switch back to `main` and sync:

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

2. Delete the merged branch (local + remote — keeps things clean):

```bash
git branch -d feature/payment-integration
git push origin --delete feature/payment-integration
```

3. Start your next task from step 5 (create a new branch off the freshly synced `main`).

---

## Quick Reference Cheat Sheet

```bash
# One-time setup
git clone https://github.com/YOUR_USERNAME/TradeX.git
cd TradeX
git remote add upstream https://github.com/NK2552003/TradeX.git

# Every time before starting new work
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
git checkout -b feature/new-task

# While working
git add .
git commit -m "feat: description"
git push origin feature/new-task

# Open PR on GitHub: fork branch -> NK2552003/TradeX main

# After merge
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
git branch -d feature/new-task
git push origin --delete feature/new-task
```

---

## Ground Rules

- ❌ Never push directly to `main` on the original repo — you don't have access anyway, but even on your fork, treat `main` as sync-only.
- ✅ One branch = one task/feature. Keep PRs small and reviewable.
- ✅ Pull `upstream/main` before starting new work, every time.
- ✅ Write clear commit messages — future us will thank you.
- ✅ If unsure about an approach before writing a lot of code, ping me first — saves rework.

That's it. If you get stuck on any git step, just share the exact error and I'll help sort it out.
