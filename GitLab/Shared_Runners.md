

# GitLab CI/CD Shared Runners: Deep Notes

## 1. Overview of GitLab CI/CD and Shared Runners

- **CI/CD Concept:**  
  GitLab CI/CD automates the build, test, and deployment processes through pipelines defined in a YAML file (commonly **.gitlab-ci.yml**).

- **Shared Runners:**  
  These are pre-configured runners hosted by GitLab that can execute your jobs on various environments. They are managed and maintained by GitLab, reducing setup overhead.

- **Types of Shared Runners:**
  - **Linux Runners:**  
    Typically use Docker-based executors or VMs; known for fast spin-up times.
  - **Windows Runners:**  
    Run on virtual machines (e.g., via Google Compute Engine), and may have longer initialization times.
  - **macOS Runners:**  
    Currently in beta and available only on premium/ultimate plans; may remain pending if not available.
  - **GPU Runners:**  
    Specialized for jobs requiring GPU acceleration.

---

## 2. Configuring the Pipeline with .gitlab-ci.yml

- **Job Definition:**  
  Each job in the pipeline is defined in the **.gitlab-ci.yml** file with its own set of instructions.

- **Using Tags to Select Runners:**  
  Tags in your job definition help GitLab match the job with the appropriate runner.  
  **Example:**

  ```yaml
  windows_job:
    tags:
      - shared-windows
    script:
      - echo "Running on Windows shared runner"
      - systeminfo

  linux_job:
    tags:
      - linux-medium
    script:
      - echo "Running on Linux shared runner"
      - cat /etc/os-release

  macos_job:
    tags:
      - sast-macos-medium-m1
    script:
      - echo "Running on macOS shared runner"
      - sw_vers
  ```

- **Key Points:**
  - **Tags:**  
    They are critical for matching a job with the correct runner based on the environment required.
  - **Parallel Execution:**  
    Jobs are executed concurrently by default, assuming matching runners are available.

---

## 3. Runner Selection and Execution Details

### a. Runner Discovery and Tag Matching

- **Runner List in GitLab:**  
  - Navigate to **Settings > CI/CD > Runners** to see available shared and project-specific runners.
  - Runners display their tags, which guide the assignment of jobs.

- **Tag Matching Mechanism:**  
  - When a pipeline is triggered, GitLab’s scheduler looks at the job's tags.
  - It then assigns the job to an active runner that has a matching tag.
  - **Example:**  
    - A job tagged with `linux-medium` will be picked by a Linux runner configured with that tag.

### b. Executor Types and Their Impact

- **Linux Runners:**  
  Often use the Docker machine executor, allowing for quick repository checkouts and fast job startup.
- **Windows Runners:**  
  Utilize virtual machines, which might add extra time for VM initialization.
- **macOS Runners:**  
  Being in beta and restricted to higher plans, jobs might remain pending if no active runner is available.

---

## 4. Pipeline Execution Flow

### a. Job Scheduling and Parallelism

- **Simultaneous Execution:**  
  Once a pipeline is triggered, GitLab schedules jobs in parallel on available runners.
  
- **Job States:**
  - **Running:**  
    The job is actively executing.
  - **Pending:**  
    Waiting for a runner (e.g., if no macOS runner is available).
  - **Cancelled:**  
    Jobs may be manually cancelled if they cannot run due to account restrictions.

### b. Troubleshooting Tips

- **Check Runner Availability:**  
  Verify under **Settings > CI/CD > Runners** that the runner with the required tag is online.
- **Account Plan Considerations:**  
  For instance, macOS runners might not be available on trial accounts because they require a premium plan.

---

## 5. Architecture Diagram

Below is a diagram that illustrates the architecture and flow of a GitLab CI/CD pipeline using shared runners:

+---------------------------+
| Developer Pushes Code     |
+-------------+-------------+
              |
              v
+---------------------------+
| GitLab Repository         |
+-------------+-------------+
              |
              v
+---------------------------+
| Pipeline Triggered        |
+-------------+-------------+
              |
              v
+---------------------------+
| Scheduler & Runner        |
| Selector                  |
+-------------+-------------+
              |
              v
+---------------------------+
| Job Tag Matching          |
+-------------+-------------+
              |
              v
+---------------------------+
| Select Appropriate Runner |
+------+------+-------------+
       |      |      
       |      |      
       v      v      
+------------+  +-------------+
| Linux      |  | Windows     |
| Shared     |  | Shared      |
| Runner     |  | Runner      |
+-----+------+  +------+------+
       |               |
       v               v
+------------+  +-------------+
| Job Exec   |  | Job Exec    |
| on Linux   |  | on Windows  |
| VM         |  | VM          |
+-----+------+  +------+------+
       \              /
        \            /
         \          /
          \        /
           v      v
+---------------------------+
|   Collect Job Logs        |
+-------------+-------------+
              |
              v
+---------------------------+
| Display Pipeline Results  |
| in GitLab UI              |
+---------------------------+


**Diagram Explanation:**
- **Push to Repository:** Code changes trigger the CI/CD pipeline.
- **Pipeline Trigger:** GitLab initiates the pipeline after detecting changes.
- **Scheduler & Runner Selector:** The scheduler assigns jobs based on tag matching.
- **Runner Allocation:** Jobs are dispatched to Linux, Windows, or macOS runners.
- **Job Execution:** Each runner spins up its environment (Docker container or VM) and executes the job.
- **Results Collection:** Logs and statuses are collected and displayed in the GitLab UI.

---

## 6. Example Walkthrough

1. **Pipeline Setup:**
   - Commit the **.gitlab-ci.yml** file containing the three jobs to your repository.
  
2. **Pipeline Trigger:**
   - GitLab automatically triggers the pipeline, and the scheduler reads the job definitions.
  
3. **Job Scheduling:**
   - **Windows Job:**  
     - Uses the tag `shared-windows` and is picked by a Windows runner.
   - **Linux Job:**  
     - Uses the tag `linux-medium` and is picked by a Linux runner with Docker.
   - **macOS Job:**  
     - Uses the tag `sast-macos-medium-m1` but may remain pending if no runner is available or if the plan doesn’t support it.

4. **Execution Details:**
   - **Linux Job:**  
     - Executes quickly due to the efficient Docker executor.
   - **Windows Job:**  
     - Takes longer due to the virtual machine initialization process.
   - **macOS Job:**  
     - May remain pending or require manual cancellation if the beta runner isn’t available.

5. **Pipeline Results:**
   - The GitLab UI displays job statuses, logs, and any issues encountered (e.g., pending macOS job).

---

## 7. Summary and Best Practices

- **Utilize Tags Wisely:**  
  Ensure each job has the correct tag to match the intended runner.
- **Monitor Runner Status:**  
  Regularly check the runner availability in your project’s settings.
- **Account Plan Awareness:**  
  Be mindful of account limitations; macOS runners are currently in beta and require a premium plan.
- **Parallel Execution:**  
  Design your pipeline so that jobs can run concurrently to speed up your CI/CD process.


These deep notes should provide a thorough understanding of GitLab CI/CD shared runners, how to configure them, and what to consider during pipeline execution. Use these insights to optimize your CI/CD pipelines effectively.
