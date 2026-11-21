---
name: x-untangle-codebase
description: "Untangle a codebase, or one area of a big one per run, so agents working in it read less per change, break less without noticing, and debug faster. Lists every structural problem, redesigns, waits for approval of batched fixes, then fixes them and checks until nothing worth fixing is left. Resumes from its decision log."
argument-hint: "[optional area or concern to focus on]"
disable-model-invocation: true
---

# Untangle Codebase

Start a thorough refactor of this codebase and complete it to the end of the agreed scope. Treat this as a goal.

**Why do this at all?**

- **Better output:** agents write better code in a well-structured codebase.
- **Cheaper & faster changes:** agents spend fewer tokens searching and more on the problem.
- **Fewer silent breaks:** agents break less without noticing.
- **Faster debugging:** agents find root causes faster.

## Scope

A run must fit in one session with good evidence for every problem. Agree the scope before step 2:

- **An argument** names an area or concern. Use it.
- **No argument, small codebase** (rough guide: under ~300 source files or ~50k lines; check with `git ls-files` and `wc -l`): the whole codebase.
- **No argument, bigger codebase:** propose 3–6 areas (top folders, packages, or features), ranked by leverage: churn and co-change from `scripts/cochange.sh`, import fan-in, size. Ask the user to pick one. The other areas are later runs.

Inside an area, list problems in it and links that cross its edge. Fix only what lies inside; write a cross-edge fix in the log as `open (other area)`.

## Ground rules

- **Never commit.** Only edit files. The user reviews and commits the diff.
- **One approval gate.** Steps 1–3 change nothing. After step 3, stop and wait for the user to approve the plan. After that, finish steps 4–5 without asking again, unless a new decision comes up that is not in the approved log.
- **Keep the decision log in `.untangle/decision-log.md`** at the repo root. Write to it as you go, so the work survives compaction. Put other notes you generate (skeletons, graphs, co-change output) in `.untangle/` too. Create `.untangle/.gitignore` with `*` in it first, so none of it shows up in git.
- **Resume, don't restart.** If `.untangle/decision-log.md` exists, read it first. If the run is for the same scope, continue from the first fix that is not `done` and skip steps 1–3. A new area, or a user asking for a new plan, starts a new section in the same log.
- **Baseline first.** Before step 2, run the project's own checks (lint, type check, tests, build) and write the results in the log. At the end you compare against this, so you can tell new failures from old ones.

## 1. Ask

Besides untangling the codebase, there are two other things you may do:

| Addition | What it does |
| --- | --- |
| **Comments** | Remove comments that only restate the code. |
| **Tests** | Remove tests that wouldn't catch a real bug, and fix the ones that fail without one. |

List these (with their exact descriptions) for the user and ask which ones to do. Then do only those.

## 2. List every problem

Don't change anything yet.

Go through the codebase asking one thing: **should these pieces change together?** Write down every place the code gets the answer wrong, as in the [decision log example](#decision-log-example). There are only three ways to get it wrong.

**Hidden links:** pieces that must change together, where the code doesn't show it.

- Copies of logic or values: change one and the others must change too, but nothing says so.
- A module that reads a global or file set by another module: change that module and this one breaks, but nothing shows it (self-contained code).
- A feature split across folders by layer, or related code in different folders: one change needs all of them, but the layout hides that (domain-driven code, colocation).
- A call order or convention callers just have to know: change it and callers break, but nothing warns them (explicit over implicit).

**Needless links:** pieces tied together that change for different reasons.

- Callers that depend on internals: the internals change for their own reasons, and the callers break anyway (encapsulation).
- Stable code that imports something more volatile: the stable code has to change whenever the volatile code does (dependency direction).
- A general function with a parameter only one workflow understands: the function has to change whenever that workflow does (caller vocabulary).
- A shallow module: its interface changes whenever its internals do, so its callers change with it (deep modules).

**Surplus:** pieces with no reason of their own to change.

- Wrappers: they only change when the thing they wrap does (pass-through wrappers).
- Extension points and config for things that never vary: nothing will ever change them (speculative generality).
- Dead code: nothing uses it, so nothing will ever need it to change.

Also write down every **special case**: code that exists for one situation instead of following from how the system works. Each one is a requirement the design never accounted for, so use them to work out what the system needs to be.

- An `if` for one value
- A parameter for a specific caller
- A swallowed exception
- A retry or sleep
- A disabled test

Count the special cases and write the number in the log. It is the main measure of progress.

## 3. Redesign from first principles

Work out the fixes as if the system had known today's requirements from the start. Look for the one fix behind several problems, which often looks nothing like them. Don't fix special cases one by one.

Ask the same thing of every fix, even one that looks better in the code: pieces that change together end up together, pieces that don't aren't tied, and everything depends on what changes less.

Write each fix above the problems it solves, as in the [decision log example](#decision-log-example).

Mark a fix with **[contract]** when it changes something outside the codebase depends on: a public API or exported package interface, a stored data format or schema, a config or env format, a CLI flag, or a new dependency. These need the user's explicit yes.

**Stop here for approval.** Show the user:

- the number of problems and special cases found,
- each fix as one line, with how many problems it solves and its size (S: one file, M: a few files, L: many files or a moved module), `[contract]` fixes first,
- the fixes grouped into batches, highest leverage first, each batch small enough to finish with green checks; ask which batches to do in this run,
- any fix where intended behavior could change, and why.

Wait for the answer. Mark fixes the user rejects as `skipped (user)` and batches left for later as `later` in the log, and leave their problems alone.

## 4. Fix everything on the list

Remove the special cases the redesign makes unnecessary, and keep the ones the system still needs. Don't go looking for bugs separately. A structural fix may fix some along the way, which is fine.

Work one batch at a time, one fix at a time. The end of each batch is a safe stop: checks green, log up to date. When a fix is decided and spans more than a few lines, hand it to the `builder` agent if you have one: name the files and the exact change, and give parallel builders files that don't overlap. After each fix, run the affected checks, then mark the fix `done` in the log. A fix that breaks behavior is not done.

If the user chose Comments:

- Comments that restate the implementation, like `// sort first so the binary search works`, only change when it does, so they have no reason of their own to change. Remove them, even if they're phrased as a why.
- Comments about something outside the code, like `// the proxy drops websockets, so we poll`, change when that does, and the code can't show it. Keep them.
- Comments that explain a workaround in the codebase, like `// wait 100ms because the cache isn't ready yet`, only change when the problem behind the workaround does. They go when the redesign removes that problem.

If the user chose Tests, do this last, because tests are your regression safety net. A test should fail on a regression, and only then:

- Tests that repeat the implementation only change when it does, so they have no reason of their own to change. They check the same interpretation against itself, so remove them.
- Tests tied to internals break when the code changes but behavior doesn't, so they change for the wrong reason. Rewrite them to depend on behavior, which changes less.
- Tests that can't fail pass whatever the code does, so no change ever affects them. They aren't checking anything, so remove them.

## 5. Check, and repeat until done

Have subagents search for special cases, hidden links, needless links and surplus. Give each one a part of the codebase, the three categories and the special-case list from step 2, and ask for findings in the log format with `file:line`. Check each finding yourself before you act on it. New findings go through steps 3–4; a new `[contract]` fix needs the user's yes first. **Do not stop until there is nothing worth fixing left in the approved batches and scope.** Findings outside them go in the log as `later` or `open (other area)`. If a round still finds about as many problems as the first list did, the scope was too big: stop at the end of the batch and propose a smaller one.

You're done when:

- **As few special cases are left in the system as possible.** How many remain is the best measure of how close you are.
- A typical change lands in one place.
- Every import is reasonable, and nothing imports anything more volatile than itself.
- Subagents have no issues left that are worth fixing.
- Intended behavior is the same as when you started, apart from bugs the refactor fixed. Test this at the end: run every baseline check again and compare.

Then report to the user:

- the scope, and the areas or batches left for later runs (rerun the skill to resume),

- special cases before → after,
- fixes done, and fixes skipped, `later`, or `open (other area)`, with the reason,
- baseline checks before → after; any new failure with its output,
- bugs the refactor fixed along the way,
- that `.untangle/` is ignored by git and can be deleted after review.

## Tips

- **Start from a skeleton:** script away the function bodies, so the whole codebase fits in context.
- **Summarize with subagents:** have them summarize parts of the codebase, so you can reason across all of it at once.
- **Check the dependency graph often:** script one that shows what imports what, and rerun it as you go.
- **Enter where leverage is highest:** start looking there first.
- **Keep a decision log:** compaction is less of a problem that way.
- **Use Git as evidence:** for how often pieces change, and what changes together. Run `scripts/cochange.sh` from this skill's folder inside the repo.

`references/tooling.md` lists skeleton and import-graph commands per ecosystem. Read it at the start of step 2.

<a id="decision-log-example"></a>
## Decision log example

The list of problems:

```md
- `ui/LogoutDialog.tsx:30` waits 100ms after closing and hopes the message input can take focus by then.
- `ui/Toolbar.tsx:40` and `ui/Menu.tsx:22` call the same actions, each with its own check for when they're disabled.
- `checkout/submit.ts:9` depends directly on `payments/stripe.ts`.
- `shortcuts/keymap.ts:18` has a switch with one case per action, separate from the menu's list.
- `ui/CommandPalette.tsx:55` keeps its own list of actions, and it's missing the newer ones.
- `ui/SettingsDialog.tsx:61` sets a global `skipRefocus` flag to stop the logout dialog it opens from sending focus to the message input.
- `history/undo.ts:30` has a special case for every action that can be undone.
- `refunds/refund.ts:22` wraps every Stripe call in `if (order.provider === "paypal")`.
- Every action handler has to call `track()` by hand, and some don't.
- `ui/Toolbar.test.tsx` and `ui/Menu.test.tsx` test the same actions separately.
```

Then with the fixes:

```md
- Make the general `Dialog` give focus back to whatever had it before it opened, so the wait and the flag can both go.
  - `ui/LogoutDialog.tsx:30` waits 100ms after closing and hopes the message input can take focus by then.
  - `ui/SettingsDialog.tsx:61` sets a global `skipRefocus` flag to stop the logout dialog it opens from sending focus to the message input.
- Define a `PaymentProvider` interface that Stripe and PayPal both implement, so checkout and refunds no longer know which one they're using.
  - `checkout/submit.ts:9` depends directly on `payments/stripe.ts`.
  - `refunds/refund.ts:22` wraps every Stripe call in `if (order.provider === "paypal")`.
- Make every user action a command with a name, a handler and an undo, so the toolbar, menu, shortcuts, palette and undo history all run from one list.
  - `ui/Toolbar.tsx:40` and `ui/Menu.tsx:22` call the same actions, each with its own check for when they're disabled.
  - `shortcuts/keymap.ts:18` has a switch with one case per action, separate from the menu's list.
  - `ui/CommandPalette.tsx:55` keeps its own list of actions, and it's missing the newer ones.
  - `history/undo.ts:30` has a special case for every action that can be undone.
  - Every action handler has to call `track()` by hand, and some don't.
  - `ui/Toolbar.test.tsx` and `ui/Menu.test.tsx` test the same actions separately.
```
