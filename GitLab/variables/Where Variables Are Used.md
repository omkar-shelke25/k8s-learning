
## Overall Context and Scope

- **Tier & Offering:**  
  The excerpt begins by noting that these variable features are available across all tiers (Free, Premium, Ultimate) and on all GitLab offerings (GitLab.com, Self‑Managed, and Dedicated). This means that regardless of your subscription or how you host GitLab, these variable usage rules apply.

- **General Concept:**  
  GitLab CI/CD allows you to define many different variables. Some of these variables are universal (usable in every aspect of the CI/CD system), while others have limitations on where they can be applied. The document explains *where* and *how* different types of variables can be used.

---

## Two Sides Where Variables Are Used

GitLab distinguishes between **two main contexts** in which variables can be used:

1. **GitLab Side – .gitlab-ci.yml File:**  
   - This is the configuration file that defines your pipeline, jobs, stages, and all job-level settings.
   - Variables in this file can affect which jobs are included, how rules are processed, and what configuration is ultimately sent to the runner.

2. **Runner Side – config.toml File:**  
   - This file configures the GitLab Runner itself.
   - Variables here affect how the runner behaves (for example, setting the runner’s environment variables or labels) and use the runner’s internal expansion mechanism.

---

## Variables in the .gitlab-ci.yml File

Within the `.gitlab-ci.yml` file, the excerpt provides a table with these columns:
- **Definition:** The job keyword or setting (e.g., `after_script`, `artifacts:name`, `script`, etc.).
- **Can be expanded?:** Indicates whether variable interpolation (substituting placeholders like `$VARIABLE`) is supported in that definition.
- **Expansion Place:** Who or what performs the expansion. This can be:
  - **Script execution shell:** Variables are expanded at runtime by the shell that runs the commands (e.g., Bash, PowerShell).  
    *Example:* In the `after_script` or `script` sections, the shell interprets `$MY_VAR` using its own rules.
  - **Runner:** The expansion is handled by GitLab Runner’s internal mechanism (using its built‑in functions, such as Go’s `os.Expand()`).  
    *Example:* In settings like `artifacts:name` or `cache:key`, GitLab Runner replaces variable placeholders before the job even starts.
  - **GitLab:** Some parts of the configuration (like `environment:name` or `include`) are processed by GitLab’s own internal engine before sending the job to the runner.

### A Few Table Examples:

- **after_script (yes, Script execution shell):**  
  Variables referenced in the commands of the `after_script` are expanded by the shell when the job runs. This means they follow the shell’s syntax rules (e.g., `$VAR` in bash).

- **artifacts:name (yes, Runner):**  
  Here, if you use a variable in the artifact’s name, the runner’s internal mechanism performs the substitution. This makes the expansion consistent across different operating systems because it happens before the runner’s shell is involved.

- **environment:name (yes, GitLab):**  
  The environment name is expanded by GitLab’s internal process. However, note that certain variables (like any starting with `CI_ENVIRONMENT_` or persisted variables) aren’t supported here. This ensures that the environment definition remains static at pipeline creation.

- **rules:if (no):**  
  For rules that determine job inclusion, variable expansion is done internally by GitLab using a strict syntax (only `$variable` form). Some variables or forms (like nested or persisted variables) aren’t supported in these expressions.

- **script (yes, Script execution shell):**  
  When you list your main commands, the runner passes them to the shell, which expands variables based on the shell’s rules. In Bash, `$VAR` is replaced; in Windows CMD, you’d use `%VAR%`; and in PowerShell, `$env:VAR` is needed.

- **variables (yes, GitLab/Runner):**  
  For the section where you define variables for a job, GitLab first performs expansion internally. Then, any variable that wasn’t recognized is passed to the runner for further expansion.

---

## Variables in the config.toml File

For the GitLab Runner configuration file (`config.toml`), only a few keys are listed:
- **runners.environment**  
- **runners.kubernetes.pod_labels**  
- **runners.kubernetes.pod_annotations**

For these, the runner itself handles variable expansion using its internal mechanism. This means that any placeholders in these settings are replaced before the runner uses them to configure job execution.

---

## Expansion Mechanisms

GitLab uses **three primary mechanisms** to expand variables, and each one operates at a different point in the pipeline lifecycle:

1. **GitLab Internal Variable Expansion Mechanism:**  
   - This occurs **before** the job is sent to a runner.
   - It processes variables found in the `.gitlab-ci.yml` file, regardless of the operating system.
   - The accepted forms are `$variable`, `${variable}`, or `%variable%`.
   - **Why?** This ensures that parts of the configuration (like include rules or environment definitions) are processed in a consistent, OS‑independent manner.

2. **GitLab Runner Internal Variable Expansion Mechanism:**  
   - Performed by the runner using methods like Go’s `os.Expand()`.
   - This mechanism handles variables in job keywords such as `cache:key` and `artifacts:paths`.
   - It only processes the `$variable` and `${variable}` forms.
   - **Note:** The expansion is done only once. Therefore, if variables refer to one another (“nested variable expansion”), the order of definitions matters. Some nested variables may or may not be fully resolved depending on configuration and whether nested expansion is enabled.

3. **Execution Shell Environment:**  
   - Once the runner hands off the job to the shell (Bash, sh, PowerShell, or CMD), the shell itself performs any variable expansion.
   - The behavior now depends on the shell’s rules:
     - **Bash/sh:** Use `$VARIABLE` or `${VARIABLE}`.
     - **Windows CMD:** Use `%VARIABLE%`.
     - **PowerShell:** Use `$env:VARIABLE`.
   - **Impact:** This phase can also handle any dynamic changes (like variables defined on the fly using export or set commands) that occur during the job’s execution.

---

## Persisted Variables

- **What Are They?**  
  Some predefined variables are “persisted” – meaning they are stored and available only at the runner or during job execution. They include sensitive tokens (such as `CI_JOB_TOKEN`) and deployment credentials.
  
- **Usage Limitations:**  
  - **Job-only:** They are available only when a runner picks up the job and runs it.
  - **Restricted Usage:** Persisted variables cannot be used in certain configuration sections such as workflow rules, includes, or triggers. This is by design to protect sensitive data from being exposed during pipeline creation.

---

## Variables with an Environment Scope

- **Definition:**  
  You can define variables that are only available for specific environments. For example, a variable like `$STAGING_SECRET` might be scoped only to environments matching `review/staging/*`.

- **Usage Example:**  
  In a job that deploys to a dynamic environment, you might reference `$STAGING_SECRET` in the rules. The job will only be created if the variable is defined in the correct environment scope.
  
- **Benefits:**  
  This allows for finer control and better security, ensuring that sensitive values are only used when the job is running in the intended environment.
Consider the following enhanced example that illustrates how GitLab CI/CD variables are processed at different stages. In this example, we’ll define global variables in our .gitlab-ci.yml file, then use them in three different places where variable expansion occurs via:

1. **GitLab’s internal expansion** (used for things like include rules or environment definitions),  
2. **Runner’s internal expansion** (used for artifacts names, cache keys, etc.), and  
3. **Shell expansion** (used when the script runs inside the job’s container).

## Example

---

```yaml
# Global variables are defined for the entire pipeline.
# These are processed early (at pipeline creation) and are available to every job.
variables:
  GREETING: "Hello"          # A simple greeting used in scripts.
  FAREWELL: "Goodbye"        # A farewell used later.
  BUILD_DIR: "build"         # Directory where build outputs are stored.
  ENVIRONMENT: "production"  # The deployment environment.

stages:
  - build
  - test

# ------------------------------------------------------
# Build Job
# ------------------------------------------------------
build_job:
  stage: build
  image: alpine:latest
  script:
    # (1) Shell Expansion:
    # At runtime, the shell (sh in Alpine) will expand these variables.
    - echo "$GREETING, world! (Shell sees: GREETING=$GREETING)"
    - mkdir -p $BUILD_DIR
    - echo "Compiled binary data" > $BUILD_DIR/app.txt
  artifacts:
    # (2) Runner Expansion:
    # The GitLab Runner processes artifacts settings before running the job.
    # Here $BUILD_DIR is replaced using the runner’s internal mechanism.
    name: "artifact_from_$BUILD_DIR"
    paths:
      - $BUILD_DIR

# ------------------------------------------------------
# Test Job
# ------------------------------------------------------
test_job:
  stage: test
  image: alpine:latest
  script:
    # (3) Predefined and global variables:
    # Some variables (like CI_PROJECT_NAME) are predefined by GitLab and are available
    # during pipeline creation. They can be used even in include rules or environment settings.
    - echo "Testing project: $CI_PROJECT_NAME"
    - echo "Deployment environment: $ENVIRONMENT"
    - cat $BUILD_DIR/app.txt
    # (4) Using a job-only variable:
    # This predefined variable (CI_JOB_ID) is only available at job runtime.
    - echo "This test job's unique ID is: $CI_JOB_ID"
```

---

### Deep Explanation of Each Part

1. **Global Variable Definition:**  
   - The top‑level `variables` section defines variables such as `GREETING`, `FAREWELL`, `BUILD_DIR`, and `ENVIRONMENT`.  
   - These values are set during the **pre‑pipeline phase**—GitLab reads them as soon as the pipeline is created. They are available for use in both GitLab’s own configuration (like in rules or environment definitions) and later for runner and shell expansion.

2. **Shell Expansion in the `script` Section:**  
   - In the `build_job`’s script, when the command  
     ```bash
     echo "$GREETING, world! (Shell sees: GREETING=$GREETING)"
     ```  
     runs, the shell inside the Alpine container replaces `$GREETING` with `"Hello"`.  
   - Similarly, `mkdir -p $BUILD_DIR` creates a directory named `build` because the shell replaces `$BUILD_DIR` with `"build"`.  
   - This is a runtime operation: the container’s shell performs the expansion according to its own syntax rules.

3. **Runner Expansion in Artifacts:**  
   - In the `artifacts` section of `build_job`, the artifact’s name is specified as:  
     ```yaml
     name: "artifact_from_$BUILD_DIR"
     ```  
   - Before the job runs, the GitLab Runner’s internal variable expansion mechanism processes this value. It replaces `$BUILD_DIR` with `"build"` to produce the artifact name `"artifact_from_build"`.  
   - This expansion happens independently of the operating system or shell since it is handled by the runner’s Go code (using methods like `os.Expand()`).

4. **Predefined Variables in Test Job:**  
   - In `test_job`, we use a predefined variable like `$CI_PROJECT_NAME` which GitLab sets before the pipeline is even executed. This shows that some variables are available during the **pre‑pipeline phase** (or at pipeline creation time) and are used to control or display configuration even before any runner picks up a job.
   - The script also prints `$ENVIRONMENT`, which comes from our global variables, and then displays the content of the artifact created in the build job.

5. **Job‑Only Variables:**  
   - The variable `$CI_JOB_ID` is a predefined variable available only at the job level (job-only). It is injected by the runner when the job starts and can be used during shell script execution.
   - This demonstrates that while some variables are expanded early in the process (GitLab side), others are only available when the runner actually executes the job.

---

## Summary of the Expansion Phases Using the Example

- **Pre-Pipeline / GitLab Internal Expansion:**  
  Global variables and predefined variables (e.g., `CI_PROJECT_NAME`, `ENVIRONMENT`) are set early. They can even be used in configuration sections like environment names or include rules.

- **Runner Expansion:**  
  Parts of the configuration such as the artifact name are processed by the GitLab Runner before the job’s container starts. This ensures a consistent value (e.g., `"artifact_from_build"`) regardless of the shell’s behavior.

- **Shell Expansion:**  
  When the job script is executed inside the container, the shell (bash/sh, PowerShell, or CMD) expands variables according to its own rules. In our Alpine container, for example, `$GREETING` and `$BUILD_DIR` are replaced at runtime.


- **Two “Sides” of Configuration:**  
  Variables are defined and used both in your pipeline configuration file (`.gitlab-ci.yml`) and in the runner’s configuration (`config.toml`).

- **Where Expansion Happens:**  
  - **GitLab’s own engine:** Processes parts of the configuration early (pre-pipeline), ensuring consistent behavior.
  - **Runner’s internal mechanism:** Processes configuration values like artifact names or cache keys.
  - **Shell execution:** Finally, when scripts run, the shell performs its own variable expansion based on the shell’s syntax.

- **Special Cases – Persisted & Environment-Scoped Variables:**  
  Persisted variables are only available at job runtime and are kept secure. Environment-scoped variables let you restrict variable availability to specific deployment targets.

