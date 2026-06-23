import Foundation

/// A combined cheat sheet for the `git` CLI and GitHub's `gh` CLI.
///
/// git and gh ship no keymap to parse: the "shortcuts" here are commands you type.
/// So the bulk is a curated table of the everyday commands, each with a `detail`
/// that teaches how it works (surfaced as a hover `?` in the overlay). On top of
/// that we read the user's own aliases — git's `[alias]` section in ~/.gitconfig
/// and gh's `aliases:` block in ~/.config/gh/config.yml — and append them as
/// `.custom`, so a personal `lg` or `prc` shows up next to the defaults.
public struct GitProvider: ShortcutProvider {
    public init() {}

    public let id = "git"
    public let displayName = "Git & GitHub"
    public let symbol = "point.3.connected.trianglepath.dotted"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = false
    public let executableNames = ["git", "gh"]
    public var defaultConfigPath: URL? { homePath(".gitconfig") }

    /// gh keeps its aliases in its own config, read in addition to ~/.gitconfig.
    private var ghConfigPath: URL { homePath(".config/gh/config.yml") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        var sections = Self.curatedSections

        var custom: [Shortcut] = []
        if let url = try? resolvedPath(configPath),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            custom += Self.parseGitAliases(text)
        }
        if let text = try? String(contentsOf: ghConfigPath, encoding: .utf8) {
            custom += Self.parseGhAliases(text)
        }
        if !custom.isEmpty {
            sections.append(Section(title: "Your aliases", shortcuts: custom))
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Alias parsing

    /// Read the `[alias]` section of a gitconfig (INI). Each `name = value` becomes
    /// `git <name>` → the command it expands to. Other sections are ignored.
    /// Best-effort: comments (`#`/`;`) and blank lines are skipped, nothing throws.
    static func parseGitAliases(_ text: String) -> [Shortcut] {
        var aliases: [Shortcut] = []
        var inAliasSection = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }

            if line.hasPrefix("[") {
                // Section header. Match `[alias]` (subsection forms aren't used for aliases).
                inAliasSection = line.lowercased().hasPrefix("[alias]")
                continue
            }
            guard inAliasSection, let eq = line.firstIndex(of: "=") else { continue }

            let name = line[line.startIndex..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { continue }
            aliases.append(Shortcut(keys: "git \(name)", action: value, source: .custom))
        }
        return aliases
    }

    /// Read the `aliases:` block of gh's config.yml. Each indented `name: value`
    /// becomes `gh <name>` → its expansion. The block ends at the next top-level
    /// key. Best-effort and defensive; nothing throws.
    static func parseGhAliases(_ text: String) -> [Shortcut] {
        var aliases: [Shortcut] = []
        var inBlock = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let indent = line.prefix { $0 == " " }.count
            if !inBlock {
                if trimmed == "aliases:" { inBlock = true }
                continue
            }
            // A non-indented line ends the block.
            if indent == 0 { break }

            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let name = trimmed[trimmed.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { continue }
            aliases.append(Shortcut(keys: "gh \(name)", action: value, source: .custom))
        }
        return aliases
    }

    // MARK: - Curated commands

    static let curatedSections: [Section] = [
        Section(title: "Branches", shortcuts: [
            Shortcut(keys: "git switch <branch>", action: "Switch branch", essential: true,
                     detail: "Moves HEAD and your working files to an existing branch, swapping the tracked files to match that branch's last commit. Your committed work on the branch you left stays exactly where it is. This is the modern, focused replacement for `git checkout <branch>` (which did too many unrelated jobs). If uncommitted edits would be clobbered by the swap, Git refuses and warns you, so commit or stash first."),
            Shortcut(keys: "git switch -c <branch>", action: "Create + switch", essential: true,
                     detail: "Creates a new branch pointing at your current commit and switches to it in one step. The branch shares all history up to now, then diverges as you commit on it. This is how you start a feature: branch off main, do the work, open a PR. Same as the older `git checkout -b`."),
            Shortcut(keys: "git switch -", action: "Previous branch",
                     detail: "Jumps back to the branch you had checked out just before this one, the same idea as `cd -` in a shell. Useful when you're bouncing between a feature branch and main to compare behaviour or copy something across."),
            Shortcut(keys: "git switch -c <b> <start>", action: "Branch from a point",
                     detail: "Creates the new branch starting from a specific commit, tag, or remote branch instead of your current HEAD. Branch off a release tag, or off the freshly-fetched remote when your local main is stale: `git switch -c hotfix origin/main`."),
            Shortcut(keys: "git branch", action: "List branches",
                     detail: "Lists your local branches and marks the current one with *. Add -a to include remote-tracking branches, or -vv to also show each branch's upstream and how far ahead or behind it sits. It only reads, it never switches anything."),
            Shortcut(keys: "git branch -d <branch>", action: "Delete branch",
                     detail: "Deletes a branch label. The commits themselves survive as long as another branch or tag still reaches them. Lowercase -d is the safe form: it refuses if the branch holds commits not merged anywhere, so you can't silently drop work. Switch to -D to force the delete once you're certain."),
            Shortcut(keys: "git branch -m <new>", action: "Rename branch",
                     detail: "Renames the current branch. To rename a different one, pass both names: `git branch -m old new`. If you've already pushed the branch, you'll also need to push the new name and delete the old one on the remote (`git push origin :old`)."),
            Shortcut(keys: "git branch -u origin/<b>", action: "Set upstream",
                     detail: "Links the current branch to a remote branch, so a bare `git push` / `git pull` knows where to go and status can show ahead/behind counts. Usually set for you the first time you run `git push -u`; this command repairs or changes it later."),
        ]),
        Section(title: "Stage & commit", shortcuts: [
            Shortcut(keys: "git status -sb", action: "Status (short)", essential: true,
                     detail: "Shows what's staged, what's modified but not staged, and what's untracked, with the branch and its ahead/behind on the first line. The two left-hand columns mean staged (left) and working tree (right). Run it constantly; it's the cheapest way to know exactly what your next commit will contain."),
            Shortcut(keys: "git add <path>", action: "Stage changes", essential: true,
                     detail: "Copies the current state of those files into the staging area (the index), the snapshot your next commit will record. Staging is deliberately separate from committing so you decide precisely what goes in. `git add .` stages everything under the current directory; `git add -p` lets you choose line by line."),
            Shortcut(keys: "git add -p", action: "Stage by hunk",
                     detail: "Walks each changed chunk and asks whether to stage it (y/n, s to split into smaller pieces, q to stop). Use it to break one sprawling edit into several clean, focused commits, or to keep a debug print unstaged while you commit the real fix around it."),
            Shortcut(keys: "git restore --staged <p>", action: "Unstage",
                     detail: "Takes a file out of the staging area but keeps your edits in the working tree, the exact opposite of `git add`. Reach for it when you staged something by mistake. Careful: drop the --staged flag and the command discards the edits instead, so keep the flag when you only mean to unstage."),
            Shortcut(keys: "git commit", action: "Commit staged", essential: true,
                     detail: "Records everything currently staged as a new commit and opens your editor for the message. Only staged content is captured; unstaged edits and untracked files are left behind for a later commit. -m \"msg\" skips the editor; -a auto-stages already-tracked files first (untracked still need an explicit add)."),
            Shortcut(keys: "git commit --amend", action: "Amend last commit",
                     detail: "Replaces the most recent commit with a fresh one that combines its changes plus anything you've staged, and lets you edit the message. Ideal for a typo or a forgotten file right after committing. Never amend a commit you've already pushed and shared: it rewrites history, and everyone else's copy diverges."),
            Shortcut(keys: "git commit --amend --no-edit", action: "Amend, keep message",
                     detail: "Folds your staged changes into the last commit without reopening the message, leaving it untouched. The everyday 'oops, forgot one file' fix. Same rule applies: don't amend a commit that's already been pushed."),
        ]),
        Section(title: "Inspect history", shortcuts: [
            Shortcut(keys: "git log --oneline --graph", action: "Commit graph", essential: true,
                     detail: "Prints history one commit per line with the branch and merge structure drawn as an ASCII graph down the left. Add --all to see every branch at once, --decorate (often on by default) to label branches and tags. The fastest way to build a mental picture of where work diverged and came back together."),
            Shortcut(keys: "git diff", action: "Unstaged diff", essential: true,
                     detail: "Shows changes in your working tree that you haven't staged yet, line by line. It compares the working tree against the index, so the moment you `git add` a change it drops out of plain `git diff`. Add --staged to see staged changes instead, or name a path to focus on one file."),
            Shortcut(keys: "git diff --staged", action: "Staged diff",
                     detail: "Shows precisely what's staged, the exact diff your next `git commit` will record. Glance at it right before committing to catch a stray debug line or an unrelated edit that snuck in. Also spelled `git diff --cached`."),
            Shortcut(keys: "git show <commit>", action: "Inspect a commit",
                     detail: "Prints a commit's metadata (author, date, message) followed by its full diff. Works on any ref: `git show HEAD`, `git show abc123`, `git show v1.2`. Append a path to see how just that one file changed in that commit."),
            Shortcut(keys: "git blame <path>", action: "Who changed each line",
                     detail: "Annotates every line of a file with the commit, author, and date that last touched it. Use it to find why a line exists, then jump to the full story with `git show <that commit>`. It's a tool for understanding history, not for assigning blame despite the name."),
        ]),
        Section(title: "Undo & fix", shortcuts: [
            Shortcut(keys: "git restore <path>", action: "Discard changes", essential: true,
                     detail: "Throws away unstaged edits to a file and restores it from the last commit (HEAD). This permanently loses those uncommitted edits, with no undo, so be sure before you run it. To pull a file's contents from a different commit instead, use `git restore --source=<commit> <path>`."),
            Shortcut(keys: "git reset --soft HEAD~1", action: "Undo commit, keep work",
                     detail: "Moves the current branch back one commit but leaves all of that commit's changes staged, as if you'd added them but not yet committed. Perfect for redoing the last commit: split it up, reword it, or add a forgotten file. HEAD~1 means 'one before HEAD'; use HEAD~2 to back up two."),
            Shortcut(keys: "git reset --hard <commit>", action: "Reset (destructive)",
                     detail: "Moves the branch to the given commit and forces your working tree and index to match it, discarding all uncommitted work plus any commits after that point on this branch. Powerful and unforgiving. Dropped commits can sometimes be recovered through `git reflog`, but discarded uncommitted edits cannot."),
            Shortcut(keys: "git revert <commit>", action: "Revert a commit",
                     detail: "Creates a new commit that applies the inverse of an earlier one, cancelling its effect while leaving history intact. This is the safe way to undo something you've already pushed, because it adds a commit rather than rewriting old ones. Contrast with reset, which rewrites and is only safe on commits no one else has."),
            Shortcut(keys: "git clean -fd", action: "Delete untracked",
                     detail: "Deletes untracked files (-f) and untracked directories (-d) from your working tree. Tracked files and gitignored files are left alone unless you also pass -x. It's destructive and nothing it removes is in a commit, so always preview first with -n (dry run)."),
        ]),
        Section(title: "Stash", shortcuts: [
            Shortcut(keys: "git stash", action: "Stash changes", essential: true,
                     detail: "Shelves your uncommitted changes to tracked files and resets the working tree to a clean HEAD, saving the changes on a stack to reapply later. Use it to switch branches or pull without committing half-finished work. Add -u to stash untracked files too, which plain stash leaves behind."),
            Shortcut(keys: "git stash pop", action: "Restore last stash",
                     detail: "Reapplies the most recent stash onto your working tree and removes it from the stack. Clean apply puts you right back where you were; a conflict is resolved like a merge (and the stash is kept until you finish). `git stash apply` does the same but leaves the stash in place."),
            Shortcut(keys: "git stash list", action: "List stashes",
                     detail: "Shows the stash stack newest-first as stash@{0}, stash@{1}, and so on, with each one's branch and message. Target a specific entry with `git stash pop stash@{2}`, or peek at it first with `git stash show -p stash@{1}`."),
        ]),
        Section(title: "Sync with remote", shortcuts: [
            Shortcut(keys: "git fetch", action: "Fetch remote",
                     detail: "Downloads new commits, branches, and tags from the remote into your remote-tracking refs (like origin/main), without touching your working tree or current branch. Always safe to run. Afterwards you can inspect origin/main or deliberately merge or rebase onto it."),
            Shortcut(keys: "git pull --rebase", action: "Pull, replay yours", essential: true,
                     detail: "Fetches the upstream branch, then replays your local commits on top of it instead of creating a merge commit, keeping history linear. This is usually what you want on a shared branch. Plain `git pull` merges instead, which scatters noisy merge commits when several people are pushing."),
            Shortcut(keys: "git push", action: "Push current branch", essential: true,
                     detail: "Uploads your local commits to the branch's upstream on the remote. It only fast-forwards: if the remote has commits you don't, Git rejects the push and you fetch and rebase first. Set the upstream once with -u and later pushes need no arguments."),
            Shortcut(keys: "git push -u origin <b>", action: "Push + set upstream",
                     detail: "Pushes a branch for the first time and records origin/<b> as its upstream, so future `git push` / `git pull` need no arguments and status shows ahead/behind. The -u (short for --set-upstream) is what you run right after creating a feature branch."),
            Shortcut(keys: "git push --force-with-lease", action: "Safe force push",
                     detail: "Force-pushes a rewritten branch (after a rebase or amend) but aborts if the remote moved since you last fetched, protecting commits a teammate pushed that you haven't seen. Always prefer this over plain --force, which overwrites blindly and can erase someone else's work."),
            Shortcut(keys: "git remote -v", action: "List remotes",
                     detail: "Lists the configured remotes with their fetch and push URLs, typically `origin` (and `upstream` if you forked). Use it to confirm where push and pull actually point before doing anything irreversible."),
        ]),
        Section(title: "Rebase & merge", shortcuts: [
            Shortcut(keys: "git merge <branch>", action: "Merge into current",
                     detail: "Brings another branch's commits into your current one. When history allows it fast-forwards; otherwise it makes a merge commit with two parents that joins the histories. It preserves exactly what happened, at the cost of a busier graph. Resolve any conflicts, stage them, then commit."),
            Shortcut(keys: "git rebase <branch>", action: "Rebase onto branch",
                     detail: "Lifts your branch's commits off and reapplies them one by one on top of <branch>, producing a clean linear history as if you'd started from the latest code. Use it to bring a feature branch up to date with main. It rewrites your commits (new hashes), so don't rebase commits others already pulled."),
            Shortcut(keys: "git rebase -i HEAD~<n>", action: "Interactive rebase", essential: true,
                     detail: "Opens an editor listing the last n commits so you can reorder, squash (combine), reword, edit, or drop them before they're reapplied. The tool for turning a messy local branch into a tidy story before opening a PR. It rewrites history, so keep it to commits you haven't pushed."),
            Shortcut(keys: "git rebase --continue", action: "Continue rebase",
                     detail: "Resumes a paused rebase after you've fixed a conflict and `git add`ed the resolved files. A rebase stops at each commit that doesn't apply cleanly: fix it, stage it, continue, and repeat until it's done."),
            Shortcut(keys: "git rebase --abort", action: "Abort rebase",
                     detail: "Cancels a rebase in progress and puts your branch back exactly as it was before you started, undoing every conflict and partial step. Your escape hatch when a rebase turns out messier than expected."),
            Shortcut(keys: "git cherry-pick <commit>", action: "Cherry-pick",
                     detail: "Copies a single commit from anywhere onto your current branch as a new commit with the same changes. Use it to grab one fix from another branch without merging the whole thing. Conflicts resolve like a merge, then `git cherry-pick --continue`."),
        ]),
        Section(title: "GitHub: pull requests", shortcuts: [
            Shortcut(keys: "gh pr create --fill", action: "Open a PR", essential: true,
                     detail: "Creates a pull request from your current branch against the repo's default branch. --fill borrows your commit messages for the title and body so you skip the prompts; drop it to write them interactively, or add -w to finish in the browser. The branch has to be pushed first (gh offers to do it)."),
            Shortcut(keys: "gh pr checkout <n>", action: "Check out a PR", essential: true,
                     detail: "Fetches the branch behind pull request number n and switches to it locally, so you can run, review, or test someone's PR on your own machine. Much easier than tracking down and fetching the contributor's branch by hand. Run it from inside the repo."),
            Shortcut(keys: "gh pr status", action: "Your PR dashboard",
                     detail: "Summarizes, for the current repo, the PRs you've opened, the ones assigned to you, and the ones asking for your review, with their CI state. A quick 'what needs my attention' check without opening a browser."),
            Shortcut(keys: "gh pr view --web", action: "Open PR in browser",
                     detail: "Opens the pull request for your current branch on github.com. Without --web it prints the PR's title, body, checks, and comments straight in the terminal. Add a number to target a specific PR instead of the current branch's."),
            Shortcut(keys: "gh pr checks", action: "PR CI status",
                     detail: "Lists every CI check on the current PR with pass/fail/pending status and links. Add --watch to keep it live until they finish. The fast way to see why a PR is red without clicking through the Actions tab."),
            Shortcut(keys: "gh pr merge", action: "Merge the PR",
                     detail: "Merges the current PR once it's approved and green. Choose the strategy with --merge, --squash, or --rebase, and add -d to delete the branch afterward; with no flags it prompts. It respects branch protection, so it refuses when required checks or reviews are missing."),
            Shortcut(keys: "gh pr diff", action: "PR diff",
                     detail: "Prints the full diff of the current PR in the terminal, so you can review the changes without leaving the shell. Add --name-only for just the list of changed files."),
        ]),
        Section(title: "GitHub: repos, issues, runs", shortcuts: [
            Shortcut(keys: "gh repo clone <owner/repo>", action: "Clone a repo",
                     detail: "Clones a GitHub repo with the remote and your auth already wired up, and for a fork it also adds an `upstream` remote pointing at the parent. You can drop the owner for your own repos: `gh repo clone my-project`."),
            Shortcut(keys: "gh repo view --web", action: "Open repo on web",
                     detail: "Opens the current repo's page on github.com. Without --web it prints the repo's description and README right in the terminal."),
            Shortcut(keys: "gh browse", action: "Browse current spot",
                     detail: "Opens the repo on github.com, and can jump straight to a file and line: `gh browse path/to/file.swift:42`. The quickest way to grab a shareable link to exactly the code you're looking at."),
            Shortcut(keys: "gh issue create -w", action: "Open an issue",
                     detail: "Creates an issue in the current repo. -w opens the browser form; drop it to fill title and body from the terminal, or pass --title and --body directly. Add --label and --assignee to set those up front."),
            Shortcut(keys: "gh issue list", action: "List issues",
                     detail: "Lists open issues for the repo. Filter with --assignee @me for yours, --label bug, --state closed, or --search for a free query. The terminal alternative to scrolling the issues tab."),
            Shortcut(keys: "gh run list", action: "List workflow runs",
                     detail: "Lists recent GitHub Actions runs with status, workflow name, branch, and run id. The starting point for checking or debugging CI from the terminal."),
            Shortcut(keys: "gh run watch", action: "Watch a run live",
                     detail: "Follows an in-progress Actions run, refreshing as jobs complete, until it finishes (and exits non-zero if it failed). Pick a run interactively or pass an id. Handy to block on CI before you merge."),
            Shortcut(keys: "gh run view --log-failed", action: "Failed run logs",
                     detail: "Prints the logs for only the failed steps of a run, so you land on the error instead of scrolling the whole log. Pass a run id or omit it to pick interactively. Use --log for the complete output."),
        ]),
    ]
}
