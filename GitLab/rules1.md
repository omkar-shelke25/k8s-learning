

### Your Understanding:
You’re thinking that `always` and `never` should be directly tied to the `if` condition, like this (hypothetically):
```yaml
if: '$CI_PIPELINE_SOURCE == "merge_request_event" then always else never'
```
This makes sense intuitively—like a single “if-then-else” statement in programming (e.g., `if (condition) { run } else { don’t run }`). But in CI/CD YAML (like GitLab’s), the `rules` keyword splits this logic into an **array of rules**, where `when: always` and `when: never` are outcomes of separate evaluations, not a single combined condition. Let’s break it down properly to resolve the confusion.

---

### How It Actually Works:
In the YAML `rules` section:
- `rules` is a **list** (array) of individual rules.
- Each rule is evaluated **in order** (top to bottom).
- The **first rule that matches** decides what happens to the job, and the rest are ignored.
- `when` is the **action** (run or skip) that happens if a rule’s condition is met—or if no prior rule applies.

Here’s the snippet again:
```yaml
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    when: always
  - when: never
```

- **Line 1 (`if` with `when: always`):** “If this condition is true, run the job.”
- **Line 2 (`when: never`):** “If no previous rule matches (e.g., the `if` was false), don’t run the job.”

The confusion arises because `when: never` looks separate, but it’s really a **fallback**—it only applies if the `if` condition fails. It’s not a direct “else” clause under the `if`; it’s a standalone rule that kicks in when nothing else matches.

---

### Deep Explanation with Examples:

#### Why `always` and `never` Are Separate:
- The `rules` array is designed to handle **multiple conditions** flexibly. You might have several `if` statements with different outcomes, and `when: never` acts as the final “default” action if none of them match.
- Think of it like a flowchart:
  1. Check Rule 1: Is `$CI_PIPELINE_SOURCE == "merge_request_event"`?
     - Yes → `when: always` → Run the job → Stop here.
     - No → Move to Rule 2.
  2. Rule 2: No condition (`when: never`) → Don’t run the job → Stop here.

#### Clearing the Confusion:
Your instinct that `always` and `never` feel like they belong to the `if` condition is spot-on for a single-case scenario. In a simple setup like this, it *behaves* like an if-then-else:
- `if true` → `always` (run).
- `if false` → `never` (don’t run).
But the YAML syntax separates them into a list to allow more complex logic (e.g., adding more `if` conditions later).

---

### Example 1: Simple Scenario (Your Current Understanding)
Let’s use a real-world app—like a to-do list website—and see how this works:

```yaml
deploy_preview:
  script:
    - echo "Deploying preview for merge request..."
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

- **Case 1: Merge Request**
  - You create a merge request to add a “delete task” feature.
  - Pipeline starts, and `$CI_PIPELINE_SOURCE = "merge_request_event"`.
  - Rule 1:
    - `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` → True (because `"merge_request_event" == "merge_request_event"`).
    - `when: always` → Job runs → Outputs: `"Deploying preview for merge request..."`.
  - Rule 2 (`when: never`) is ignored because Rule 1 matched.

- **Case 2: Regular Push**
  - You push a typo fix to the `feature/delete-task` branch.
  - Pipeline starts, and `$CI_PIPELINE_SOURCE = "push"`.
  - Rule 1:
    - `if: '$CI_PIPELINE_SOURCE == "merge_request_event"'` → False (because `"push" ≠ "merge_request_event"`).
    - Move to Rule 2.
  - Rule 2:
    - `when: never` → Job is skipped → No output, no deployment.

**Your Confusion Resolved:**
- It *feels* like `when: always` and `when: never` should be one rule (e.g., “if true then always, else never”), but they’re split into two rules. The `when: never` only applies when the `if` fails, acting like an “else” in practice.

---

### Example 2: Why the Separation Makes Sense
Now let’s add complexity to show why `rules` uses a list instead of a single if-then-else:

```yaml
deploy_preview:
  script:
    - echo "Deploying preview..."
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: always
    - when: never
```

- **Case 1: Merge Request**
  - `$CI_PIPELINE_SOURCE = "merge_request_event"`, `$CI_COMMIT_BRANCH = "feature/delete-task"`.
  - Rule 1: `if` true → `when: always` → Job runs → Stop here.
- **Case 2: Push to `main`**
  - `$CI_PIPELINE_SOURCE = "push"`, `$CI_COMMIT_BRANCH = "main"`.
  - Rule 1: `if` false → Next rule.
  - Rule 2: `if` true → `when: always` → Job runs → Stop here.
- **Case 3: Push to Another Branch**
  - `$CI_PIPELINE_SOURCE = "push"`, `$CI_COMMIT_BRANCH = "feature/delete-task"`.
  - Rule 1: `if` false → Next rule.
  - Rule 2: `if` false → Next rule.
  - Rule 3: `when: never` → Job skipped.

**Key Insight:**
- The separation allows multiple `if` conditions. If `always` and `never` were locked into one `if` statement, you couldn’t add a second condition (like checking the branch name) without rewriting everything. The list structure is more flexible.

---

### Rewriting to Match Your Intuition (Hypothetical):
If GitLab worked the way you’re imagining (one condition with direct outcomes), it might look like this:
```yaml
deploy_preview:
  script:
    - echo "Deploying preview..."
  rules:
    if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      then: always
      else: never
```
- This would mean: “If merge request, run; otherwise, don’t.”
- But real YAML doesn’t use `then`/`else`—it uses the `rules` array instead, splitting `always` and `never` into separate entries.

---

### Deep Production Example:
For a banking app:
```yaml
deploy_review_app:
  script:
    - echo "Deploying review app for MR #$CI_MERGE_REQUEST_IID"
    - ./deploy.sh
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      when: always
    - when: never
```

- **Developer Action:**
  - Pushes to `feature/add-transfers` → `$CI_PIPELINE_SOURCE = "push"`.
  - Rule 1 fails → `when: never` → No deployment (saves resources).
  - Creates merge request #12 → `$CI_PIPELINE_SOURCE = "merge_request_event"`.
  - Rule 1 succeeds → `when: always` → Outputs: `"Deploying review app for MR #12"`, runs `deploy.sh`.

- **Why Separate?**
  - Later, you might add: `if: '$CI_COMMIT_BRANCH == "staging"' when: always` to also deploy for pushes to `staging`. The list structure makes this easy without breaking the merge request logic.

---

### Final Clarity:
- **Your Thought:** `always` and `never` feel like they should be one `if` condition’s outcomes (then/else). That’s logical!
- **Reality:** They’re separate rules in a list. `when: always` applies if the `if` matches; `when: never` is a fallback if it doesn’t.
- **Fixing Confusion:** Think of `when: never` as “the default if nothing else works,” not a direct partner to the `if`. The list evaluates sequentially.

