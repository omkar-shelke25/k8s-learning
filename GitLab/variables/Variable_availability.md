

### Overall Context

**Predefined Variables:**  
These are environment variables that GitLab sets automatically. They carry metadata about the pipeline, project, commit, runner, and more. They help you control or customize the pipeline behavior without manually setting every variable.

**Pipeline Execution Phases:**  
GitLab pipelines run through several stages. At different phases, different sets of variables become “visible” or usable. The text identifies three distinct phases:
1. **Pre-pipeline**
2. **Pipeline**
3. **Job-only**

---

### Pre-pipeline Phase

**Pre-pipeline Variables:**  
- **When They’re Available:**  
  These variables exist **before** the pipeline is created. This means they are determined as soon as GitLab starts processing the configuration, even before any jobs or stages are defined.
  
- **Usage Context:**  
  They are unique in that they can be used with **`include:rules`**.  
  - **include:rules:**  
    This is a mechanism in GitLab CI/CD that lets you conditionally include external configuration files. The rules that decide which configuration files to include can only evaluate variables available in the pre-pipeline phase.  
  - **Control Over Configuration Files:**  
    Because these variables are available early, they let you decide which parts of the CI/CD configuration to load, thus influencing the pipeline’s structure from the very beginning.

**Key Point:**  
Pre-pipeline variables are critical for determining the overall pipeline configuration. Since they are available before the pipeline is fully defined, they offer the first level of control over which jobs and settings will eventually run.

---

### Pipeline Phase

**Pipeline Variables:**  
- **When They’re Available:**  
  These become accessible **when GitLab is creating the pipeline**—after the pre-pipeline phase but before any individual job execution. At this moment, the pipeline structure is being determined.

- **Usage Context:**  
  They, along with the pre-pipeline variables, are used to:
  - **Configure Rules in Jobs:**  
    Many jobs have rules (conditions) that determine if they should run. Pipeline variables help evaluate these rules.  
  - **Determine Which Jobs to Add:**  
    Based on these rules, the system decides which jobs are included in the pipeline. If a rule evaluates to false (for example, if a condition based on a pipeline variable is not met), the corresponding job may be skipped or not created at all.

**Key Point:**  
Pipeline variables play a central role in shaping the execution of the pipeline. They are used during the pipeline’s assembly to fine-tune which jobs will eventually run, based on the conditions defined in the configuration.

---

### Job-only Phase

**Job-only Variables:**  
- **When They’re Available:**  
  These variables become available **only when a runner picks up the job and runs it.**  
  - **Runner:**  
    A runner is an agent (a machine or container) that executes the job. It is at this stage that the job’s execution environment is prepared, including the injection of job-only variables.
  
- **Usage Context:**  
  These variables can be used in:
  - **Job Scripts:**  
    The actual code or commands you write in your job’s script can reference these variables. They help in customizing the behavior of the job at runtime.
  
- **Limitations:**  
  They have several restrictions:
  - **Cannot Be Used with Trigger Jobs:**  
    If you have a job that triggers another pipeline (a downstream pipeline), job-only variables aren’t forwarded or available for controlling that trigger.
  - **Cannot Be Used with Workflow, Include, or Rules:**  
    - **Workflow:**  
      This refers to the higher-level configuration that defines the overall pipeline process.
    - **Include:**  
      The mechanism for importing additional configuration files.
    - **Rules:**  
      The conditions that determine job inclusion or behavior.  
    Because these variables only become available when the job is already running, they cannot be used to influence decisions made earlier (like which jobs to run or which configuration files to include).

**Key Point:**  
Job-only variables are meant solely for the job’s runtime environment. They provide dynamic data during job execution but cannot affect the pipeline’s construction or configuration.

---

### Summarized Relationships and Use-Cases

1. **Pre-pipeline Variables:**  
   - **Purpose:** Decide early configuration (like which YAML files to include) using include:rules.  
   - **Availability:** Before pipeline creation.

2. **Pipeline Variables:**  
   - **Purpose:** Influence which jobs get added by evaluating job rules.  
   - **Availability:** At pipeline creation time.

3. **Job-only Variables:**  
   - **Purpose:** Influence job behavior during execution (e.g., customizing scripts, paths, secrets, etc.).  
   - **Availability:** Only when the job is executed by a runner, hence not available for pipeline-level decisions.

---

### Final Thoughts

Each phase and type of variable is designed to scope the influence of variables appropriately:
- **Early-stage variables (Pre-pipeline and Pipeline)** influence the structure and flow of the pipeline.
- **Late-stage variables (Job-only)** affect how individual jobs run without influencing overall pipeline design.

