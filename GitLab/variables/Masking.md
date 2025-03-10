

## 1. Overview of CI/CD Variables

- **Purpose:**  
  CI/CD variables allow you to store and manage sensitive information (e.g., passwords, tokens) outside of your source code. This approach prevents hardcoding secrets in repositories, which enhances security and maintainability.

- **Variable Types and Levels:**  
  - **Key-Value Pair vs. File Type:**  
    You can create simple key-value pair variables or upload files as variables depending on your needs.  
  - **Scope:**  
    Variables can be defined at different levels:
    - **Project Level:** Specific to one project.
    - **Group Level:** Inherited by all projects under a group.
  - **Limit:**  
    Each project can have up to 8,000 variables.

---

## 2. Creating and Masking Variables

### Step-by-Step Process

1. **Navigate to CI/CD Settings:**
   - Access your repository’s settings and then select the **CI/CD** section.
   - Within this section, find the **Variables** option.

2. **Adding a New Variable:**
   - Click on the option to add a variable.
   - **Key and Value:**  
     - Enter a unique key (e.g., `docker_password`).
     - Provide the corresponding sensitive value (e.g., `secure password`).

3. **Configuring Variable Attributes:**
   - **Masked Variable:**  
     - Select the mask option. This ensures that the value will be hidden (i.e., replaced with asterisks) in job logs.  
     - *Note:* Although masked in logs, any user with access to CI/CD settings can still view or edit the actual value.
   - **Protected Variable (Optional):**  
     - If you mark a variable as protected, it will only be available in pipelines running on protected branches. This adds an extra layer of security for deployment environments.

4. **Save the Variable:**  
   - After setting the attributes and confirming the details, add the variable to your project settings.

---

## 3. Using Masked Variables in the Pipeline

- **Reference in Job Scripts:**  
  - Within your `.gitlab-ci.yml` file, use the dollar syntax to refer to the variable (e.g., `$docker_password`).
  - This syntax allows the variable to be available across multiple jobs if it’s set at a global level.

- **Example Usage in a Job:**
  ```yaml
  deploy:
    stage: deploy
    script:
      - echo "Deploying with password: $docker_password"  # The actual value will be masked in logs.
  ```

- **Log Masking:**  
  - When the job runs, the actual password is not revealed in the logs, which protects the sensitive data from being exposed during pipeline execution.

---

## 4. Handling Pipeline Jobs and Hidden Jobs

### Hidden Jobs

- **Purpose of Hidden Jobs:**  
  - Hidden jobs are jobs prefixed with a dot (`.`). They are visible in the pipeline editor but are not executed by default. This can be useful for debugging or temporarily disabling parts of your pipeline without removing the configuration.

- **Impact on Pipeline Execution:**  
  - When you hide a job (by adding a dot before the job name), dependencies that expect outputs from these jobs might cause errors.
  - In the demo, after hiding certain jobs, the pipeline ran only two jobs. However, if a subsequent job depends on artifacts or outputs from the hidden job, it may fail.

### Example Scenario

- **Docker Push Job:**  
  - The job successfully retrieves the masked variable and uses it, ensuring that the password remains hidden in logs.
- **Deploy Job Failure:**  
  - In the demonstration, the deploy job failed because it depended on a file (e.g., `dragon.txt`) that was not created. This failure illustrates the importance of ensuring all dependencies are met when selectively hiding jobs.

---

## 5. Best Practices and Considerations

- **Security First:**  
  - Always store sensitive values as variables rather than hardcoding them. Use masking and protection features to prevent accidental exposure.
  
- **Access Control:**  
  - Remember that users with CI/CD settings access can view and modify these variables. Ensure that only trusted team members have access.

- **Environment-Specific Variables:**  
  - You can associate variables with specific environments (e.g., staging, production) to control which values are used during deployments.

- **Testing Pipelines:**  
  - When modifying or hiding jobs, double-check job dependencies to avoid pipeline failures. Use the pipeline editor and visualizer to inspect job relationships.

- **Documentation and Maintenance:**  
  - Keep your CI/CD variable configurations documented. This practice helps maintain clarity when managing multiple variables across projects or groups.

---

## 6. Summary

Masking variables in CI/CD is a critical practice for secure pipeline execution. By:
- Creating variables at the project or group level,
- Masking sensitive data to hide it in logs,
- Optionally protecting variables to restrict usage to specific branches,
- And carefully managing job dependencies (especially when using hidden jobs),

you can ensure that your sensitive information remains secure while enabling flexible and maintainable CI/CD processes.

---

