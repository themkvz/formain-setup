---
name: x-write-tests
description: >-
  Best practices for writing, structuring, reviewing, and pruning test cases (unit, integration,
  E2E, and Robot Framework). Use automatically whenever starting to write new tests, add test
  coverage, add regression tests, refactor tests, or prune low-value tests. Ensures every test
  guards intended behavior, stays readable and repeatable, and avoids fragile, redundant, or
  implementation-coupled checks.
---

# Write Tests

Every test must guard intended behavior, read like a clear scenario, and fail only on a real regression. Apply these rules both when writing new tests and when editing or pruning existing ones.

## 1. Guard intended behavior (write and prune gate)

Before adding a test — and whenever reviewing existing tests — check what it depends on. Keep or write a test **only** if it changes solely when intended behavior changes and fails solely when that behavior regresses.

Reject or prune any test that depends on:

- **The past**: asserts removed code stays gone, or that a moved module is absent from its old path. Bringing removed code back is a decision, not a regression.
- **Nothing**: no real code change can make it fail.
  - Testing the browser, runtime, or framework itself (a `<button>` renders, a click event fires).
  - Mocking the unit under test and asserting what the mock returns.
  - Re-asserting what the type system already guarantees.
- **The implementation**: breaks on refactors when behavior did not change, or still passes when behavior is wrong.
  - Deriving expected values using the same formula/logic as the production code. Use concrete expected values instead.
  - Asserting private state, internal call order, or which internal helper was invoked instead of observable caller-facing behavior.
- **Duplicates**: another test (for example, an integration or checkout test) already guards the same behavior.

Additional rules:

- **No test-only production code**: never add `_resetForTests()` or `_getInternalState()` helpers to production code; remove existing ones when pruning the tests that depended on them.
- **Rewrite vs. delete**: if a fragile test still covers behavior callers rely on, rewrite it against the observable contract instead of deleting coverage. Never delete a failing test just to make checks pass.

## 2. Structure and readability

- Separate setup/config, test data, test cases, and reusable helpers cleanly. Only include sections that serve a purpose.
- Write each test as a scannable flow (**Arrange / Act / Assert** or **Given / When / Then**) with one logical action per step.
- Keep indentation, spacing, and naming consistent across the suite. Use blank lines only to separate logical blocks.
- Comments explain *why* (assumptions, constraints, unusual behavior), never narrate what the next line already says.

## 3. Test data, variables, and secrets

- Put repeated or meaningful values into descriptively named variables, constants, or fixtures rather than hardcoding literals across steps.
- **Never hardcode credentials, tokens, or secrets** in test files or committed variables; use the environment's approved secret mechanism.
- Keep environment-specific config (URLs, endpoints, orgs) externalized and manageable.
- Use valid test data that respects real domain constraints (required fields, validation rules, types, permissions).
- Make tests repeatable and isolated: create unique, test-owned records so repeated or parallel runs do not collide on duplicates or shared mutable state.

## 4. Setup, teardown, and safe cleanup

- Use suite-level setup (`beforeAll`, `Suite Setup`) only when multiple tests genuinely share the same prerequisite or session. Keep per-test starting state inside each test or local fixture — overusing shared setup creates hidden dependencies.
- Design teardown for partial failures: cleanup must run safely if a test fails halfway through, remove only test-owned data/resources, and never delete state another test depends on.

## 5. Reusable helpers without hiding intent

- Tests should communicate *what* business scenario is being verified; helpers, fixtures, or keywords handle repeated *how*.
- Give helpers clear purpose-driven names, focus each on one understandable task, accept parameters for varying inputs, and avoid cross-test state.
- Keep granularity balanced: do not hide ten unrelated operations inside one opaque helper, and do not wrap every trivial one-liner.

## 6. Assertions and locators

- **Never confuse completing an action with passing a test.** Clicking, saving, or calling a function proves nothing until you verify the resulting state.
- Think in three stages: **Action** (run the business operation) -> **Verification** (assert observable state) -> **Outcome** (clear failure showing which requirement broke).
- Assert requirements, not incidental UI or implementation details.
- For UI/E2E tests, prefer semantic, accessible, or metadata-aware locators (`getByRole`, `getByLabel`, `getByTestId`, library semantic locators) over brittle DOM/CSS selectors tied to layout.
- Confirm exact library APIs, matchers, and keyword signatures against the version installed in the project rather than assuming examples work everywhere.

## 7. Robot Framework (`.robot`) specifics

When authoring `.robot` files:

- Use only the sections needed (`*** Settings ***`, `*** Variables ***`, `*** Test Cases ***`, `*** Keywords ***`) with valid section headers.
- Indent test and keyword steps consistently (4 spaces) and separate keywords from arguments with 2+ spaces.
- Scope `Suite Setup` and `Suite Teardown` strictly to shared prerequisites and test-owned cleanup.
- Verify library keywords (for example QForce / CRT keywords) and metadata-aware locators against the environment's supported keyword reference before execution.

## Examples

```diff
--- a/pricing.test.ts
+++ b/pricing.test.ts
@@ rewritten: expected value repeated the code's logic @@
 test("applies the discount", () => {
-  const price = 100;
-  expect(applyDiscount(price, 0.2)).toBe(price - price * 0.2);
+  expect(applyDiscount(100, 0.2)).toBe(80);
 });
--- a/cart.test.ts
+++ b/cart.test.ts
@@ rewritten against what callers see: asserted private state @@
 test("adds an item to the cart", () => {
   const cart = new Cart();
   cart.add(book);
-  expect(cart._items.length).toBe(1);
+  expect(cart.total()).toBe(book.price);
 });
@@ deleted: checkout.test.ts already guards the same total @@
-test("total includes tax", () => {
-  expect(cartTotal([book], { tax: 0.1 })).toBe(11);
-});
--- a/export.test.ts
+++ b/export.test.ts
@@ deleted: guards code that no longer exists @@
-test("legacy exporter is gone", () => {
-  expect(existsSync("src/export/legacy.ts")).toBe(false);
-});
--- a/session.test.ts
+++ b/session.test.ts
@@ deleted, with the production code that only existed for it @@
-test("clears the cache", () => {
-  _resetCacheForTests();
-  expect(_getCacheSize()).toBe(0);
-});
--- a/session.ts
+++ b/session.ts
@@ @@
-export function _resetCacheForTests() { cache.clear(); }
-export function _getCacheSize() { return cache.size; }
```

## Done checklist

- Every test is anchored to intended behavior and fails on — and only on — a regression.
- No test asserts removed code, platform/type guarantees, private state, or logic-derived expected values.
- No two tests guard the same behavior; no production code exists only for tests.
- Test data is descriptive, isolated, repeatable, and free of hardcoded secrets.
- Setup and teardown are scoped and safe on partial failure; assertions verify the real outcome.
