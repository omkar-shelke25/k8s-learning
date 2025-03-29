

### What is the `extends` Keyword?

The `extends` keyword in GitLab CI/CD allows a job to inherit configuration from another job, reducing duplication and centralizing reusable settings. It’s one of three optimization techniques mentioned in GitLab’s documentation (alongside YAML anchors/aliases and `!reference` tags), but `extends` is particularly powerful for reusing job definitions.

#### Key Concepts:
1. **Hidden Jobs**: Jobs starting with a dot (e.g., `.hidden_job`) are not executed directly in the pipeline. They act as templates or blueprints that other jobs can extend.
2. **Inheritance**: When a job uses `extends`, it copies all the configuration from the referenced job(s) and merges it with its own settings.
3. **Merging**: If the extending job defines the same keys (e.g., `script`), GitLab merges them according to specific rules (more on this later).
4. **Multi-Level Inheritance**: A job can extend another job that itself extends another, up to 11 levels, though GitLab recommends limiting it to 3 for simplicity.

---

### Why Use `extends`?

- **DRY (Don’t Repeat Yourself)**: Avoid duplicating common settings across jobs.
- **Maintainability**: Update one hidden job, and all jobs extending it inherit the changes.
- **Clarity**: Keep `.gitlab-ci.yml` concise and focused on job-specific logic.

---

### Example Scenario: Optimizing a Node.js Pipeline

Let’s assume your current `.gitlab-ci.yml` contains a `test` stage with two jobs: `unit_tests` and `code_coverage`. Both are Node.js-based and share a lot of setup code (image, services, variables, cache, before_script). You want to refactor this using `extends` to eliminate duplication.

#### Original `.gitlab-ci.yml` (Before Refactoring)
```yaml
stages:
  - test
  - build
  - deploy

variables:
  NODE_ENV: "test"

unit_tests:
  stage: test
  image: node:18-alpine
  services:
    - name: mongo:5
      alias: db
  variables:
    DB_HOST: "db"
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npm test
  artifacts:
    reports:
      junit: test-results.xml

code_coverage:
  stage: test
  image: node:18-alpine
  services:
    - name: mongo:5
      alias: db
  variables:
    DB_HOST: "db"
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npm run coverage
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    paths:
      - coverage/

# Commented out for focus on test stage
# build_docker:
#   stage: build
#   script:
#     - echo "Building Docker image..."

# deploy_eks:
#   stage: deploy
#   script:
#     - echo "Deploying to EKS..."
```

**Observations:**
- **Duplication**: `unit_tests` and `code_coverage` share identical `image`, `services`, `variables` (local ones), `cache`, and `before_script`.
- **Unique Parts**: Only `script`, `artifacts`, and `coverage` differ.
- **Line Count**: Around 40 lines, with ~20 duplicated.

#### Step 1: Create a Hidden Job
A hidden job starts with a dot (e.g., `.prepare_nodejs_env`) and contains the shared configuration.

**Refactored `.gitlab-ci.yml` with Hidden Job:**
```yaml
stages:
  - test
  - build
  - deploy

variables:
  NODE_ENV: "test"

# Hidden job for shared Node.js setup
.prepare_nodejs_env:
  image: node:18-alpine
  services:
    - name: mongo:5
      alias: db
  variables:
    DB_HOST: "db"
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - node_modules/
  before_script:
    - npm ci

unit_tests:
  extends: .prepare_nodejs_env
  stage: test
  script:
    - npm test
  artifacts:
    reports:
      jupyter: test-results.xml

code_coverage:
  extends: .prepare_nodejs_env
  stage: test
  script:
    - npm run coverage
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    paths:
      - coverage/

# Commented out for focus
# build_docker:
#   stage: build
#   script:
#     - echo "Building..."

# deploy_eks:
#   stage: deploy
#   script:
#     - echo "Deploying..."
```

**What Changed?**
- **Hidden Job**: `.prepare_nodejs_env` encapsulates the shared setup (image, services, variables, cache, before_script).
- **Extends**: Both `unit_tests` and `code_coverage` use `extends: .prepare_nodejs_env` to inherit the setup.
- **Line Count**: Reduced from ~40 to ~25 lines by removing duplication.
- **Visualization**: `.prepare_nodejs_env` doesn’t appear in the pipeline UI because it’s hidden; only `unit_tests` and `code_coverage` run.

---

### How `extends` Works: Merging Rules

When a job extends another, GitLab merges their configurations. Here’s how it handles key fields:

1. **Scalar Values (e.g., `image`, `stage`)**:
   - The extending job’s value overrides the hidden job’s value.
   - Example: If `unit_tests` sets `image: node:20`, it overrides `.prepare_nodejs_env`’s `image: node:18-alpine`.

2. **Arrays (e.g., `script`, `before_script`)**:
   - The extending job’s array overrides the hidden job’s array (no appending).
   - Example: `.prepare_nodejs_env` has `before_script: [npm ci]`, and `unit_tests` has `script: [npm test]`. The `before_script` is inherited, but `script` is unique to `unit_tests`.

3. **Hashes (e.g., `variables`, `artifacts`)**:
   - Nested key-value pairs are merged recursively.
   - Example: If `.prepare_nodejs_env` has `variables: { DB_HOST: "db" }` and `unit_tests` has `variables: { TEST_MODE: "unit" }`, the result is `{ DB_HOST: "db", TEST_MODE: "unit" }`.

#### Example with Overrides:
```yaml
.prepare_nodejs_env:
  image: node:18-alpine
  script:
    - echo "Default script"
  variables:
    DB_HOST: "db"

unit_tests:
  extends: .prepare_nodejs_env
  image: node:20  # Overrides image
  script:         # Overrides script
    - npm test
  variables:      # Merges with inherited variables
    TEST_MODE: "unit"
```

**Merged Result (Full Config View):**
```yaml
unit_tests:
  image: node:20
  script:
    - npm test
  variables:
    DB_HOST: "db"
    TEST_MODE: "unit"
```

---

### Multi-Level Inheritance

You can chain `extends` across multiple levels. Let’s add a second hidden job for testing-specific settings.

#### Example: Multi-Level Inheritance
```yaml
stages:
  - test

# Base Node.js setup
.prepare_nodejs_env:
  image: node:18-alpine
  before_script:
    - npm ci

# Test-specific setup
.nodejs_test_base:
  extends: .prepare_nodejs_env
  stage: test
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - node_modules/

unit_tests:
  extends: .nodejs_test_base
  script:
    - npm test
  artifacts:
    reports:
      junit: test-results.xml
```

**How It Works:**
- `.prepare_nodejs_env`: Defines the Node.js environment.
- `.nodejs_test_base`: Extends `.prepare_nodejs_env` and adds test-specific settings (stage, cache).
- `unit_tests`: Extends `.nodejs_test_base`, inheriting both levels, and adds its own `script` and `artifacts`.
- **Merged Result**: Includes `image`, `before_script`, `stage`, `cache`, `script`, and `artifacts`.

**Recommendation**: GitLab suggests limiting to 3 levels (e.g., `.base > .test_base > unit_tests`) to avoid complexity.

---

### Combining `extends` with `include`

You can use `extends` with `include` to pull hidden jobs from external files.

#### Example: External Hidden Job
**`common.yml`:**
```yaml
.prepare_nodejs_env:
  image: node:18-alpine
  before_script:
    - npm ci
```

**`.gitlab-ci.yml`:**
```yaml
include:
  - local: 'common.yml'

stages:
  - test

unit_tests:
  extends: .prepare_nodejs_env
  stage: test
  script:
    - npm test
```

- `include` imports the hidden job from `common.yml`.
- `unit_tests` extends it, reusing the external configuration.

---

### Practical Example: Running the Pipeline

Let’s commit the refactored `.gitlab-ci.yml` and see it in action.

1. **Commit Message**: "Refactor test stage with extends keyword"
2. **Pipeline Trigger**: Push to a feature branch (e.g., `feature/extends-demo`).
3. **Pipeline View**: Only `unit_tests` and `code_coverage` appear, running with inherited settings.

**Job Logs (unit_tests):**
```
Pulling image node:18-alpine...
Restoring cache for key feature/extends-demo...
Running before_script: npm ci
Running script: npm test
Uploading artifacts: test-results.xml
```

**Full Config View (via GitLab UI):**
- Click “Full configuration” in the pipeline editor to see the merged YAML, confirming `image`, `before_script`, etc., are applied.

---

### Advantages of This Approach

1. **Reduced Duplication**: From 20 duplicated lines to 1 hidden job.
2. **Easier Updates**: Change `.prepare_nodejs_env` (e.g., update `image` to `node:20`), and both jobs inherit it.
3. **Scalability**: Add more test jobs (e.g., `integration_tests`) with `extends: .prepare_nodejs_env`.

---

### Debugging and Validation

- **Pipeline Editor**: Use GitLab’s built-in editor to validate syntax (`Ctrl + S` or “Validate” tab).
- **Full Config**: Check the merged YAML to ensure inheritance works as expected.
- **Warnings**: A hidden job can’t be blank; it needs at least one key (e.g., `image`).

---

### Conclusion

The `extends` keyword is a powerful tool for optimizing GitLab CI/CD configurations. By using hidden jobs like `.prepare_nodejs_env`, you can centralize shared settings, reduce duplication, and make your pipelines more maintainable. It supports multi-level inheritance for complex setups and pairs beautifully with `include` for modularity. In your Node.js example, refactoring `unit_tests` and `code_coverage` cut lines significantly while keeping the pipeline functional and flexible.

Let me know if you’d like to explore multi-level examples further, dive into merging edge cases, or integrate this with other features!
