# Kubernetes SecurityContext Notes

## Overview
- **SecurityContext**: Defines privilege and access control settings for Pods or Containers in Kubernetes.
- **Scope**:
  - **Pod-Level**: Applies to all containers in the Pod and affects volumes (e.g., `fsGroup`, `seLinuxOptions`).
  - **Container-Level**: Applies to a specific container, overrides pod-level settings where applicable (e.g., `runAsUser`, `capabilities`).

## Key Security Settings
- **Discretionary Access Control (DAC)**: Permissions based on user ID (UID) and group ID (GID).
- **Security Enhanced Linux (SELinux)**: Assigns security labels to objects.
- **Privileged vs. Unprivileged**: Controls whether a container runs with elevated privileges.
- **Linux Capabilities**: Grants specific root-like privileges without full root access.
- **AppArmor**: Restricts program capabilities using profiles.
- **Seccomp**: Filters system calls for a process.
- **allowPrivilegeEscalation**: Controls if a process can gain more privileges than its parent (set to `false` for security).
- **readOnlyRootFilesystem**: Mounts container’s root filesystem as read-only (container-level only).
- **fsGroup**: Sets group ID for volume ownership, applies to all containers in the Pod.
- **supplementalGroups**: Additional group IDs for container processes.
- **supplementalGroupsPolicy** (Kubernetes v1.33, beta): Controls merging of `/etc/group` from container image:
  - **Merge** (default): Includes groups from `/etc/group`.
  - **Strict**: Only uses `fsGroup`, `runAsGroup`, `supplementalGroups`.

## Pod-Level SecurityContext
- **Applies to**: All containers and volumes in the Pod.
- **Settings**:
  - `runAsUser`: Sets UID for all containers (e.g., `1000`).
  - `runAsGroup`: Sets primary GID (e.g., `3000`).
  - `fsGroup`: Sets GID for volumes (e.g., `2000`).
  - `supplementalGroups`: Additional GIDs for processes (e.g., `[4000]`).
  - `seLinuxOptions`: Applies SELinux labels (e.g., `level: "s0:c123,c456"`).
  - `supplementalGroupsPolicy`: Controls group merging (`Merge` or `Strict`).
  - `fsGroupChangePolicy`: Controls volume permission changes:
    - `OnRootMismatch`: Changes permissions only if root directory mismatches.
    - `Always`: Always changes permissions on mount.
- **Limitations**: Cannot set `capabilities`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, `seccompProfile`, or `appArmorProfile`.

## Container-Level SecurityContext
- **Applies to**: Specific container, overrides pod-level settings.
- **Settings**:
  - `runAsUser`: Overrides pod-level UID (e.g., `2000`).
  - `allowPrivilegeEscalation`: Prevents privilege escalation (e.g., `false`).
  - `readOnlyRootFilesystem`: Enforces read-only filesystem (e.g., `true`).
  - `capabilities`: Adds/removes Linux capabilities (e.g., `add: ["NET_ADMIN", "SYS_TIME"]`).
  - `seccompProfile`: Sets Seccomp profile (e.g., `type: RuntimeDefault` or `Localhost` with `localhostProfile`).
  - `appArmorProfile`: Sets AppArmor profile (e.g., `type: RuntimeDefault` or `Localhost` with `localhostProfile`).
  - `seLinuxOptions`: Applies container-specific SELinux labels.

## Example Configurations
### Pod-Level Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    supplementalGroups: [4000]
    supplementalGroupsPolicy: Strict
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  containers:
  - name: sec-ctx-demo
    image: busybox:1.28
    command: ["sh", "-c", "sleep 1h"]
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      allowPrivilegeEscalation: false
```
**Explanation**:
- All containers run as UID `1000`, GID `3000`.
- Volumes use GID `2000` (`fsGroup`).
- Processes have supplemental group `4000`.
- `Strict` policy prevents merging groups from `/etc/group`.
- Container prevents privilege escalation.

### Container-Level Example
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo proliferation
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: sec-ctx-demo
    image: gcr.io/google-samples/hello-app:2.0
    securityContext:
      runAsUser: 2000
      allowPrivilegeEscalation: false
      capabilities:
        add: ["NET_ADMIN"]
      seccompProfile:
        type: RuntimeDefault
      appArmorProfile:
        type: RuntimeDefault
```
**Explanation**:
- Pod sets default `runAsUser: 1000`, overridden by container’s `runAsUser: 2000`.
- Container adds `NET_ADMIN` capability, uses default Seccomp and AppArmor profiles, and disables privilege escalation.

## Real-Life Analogy: Office Building
- **Pod-Level**: Building-wide security policy (e.g., employee ID for all offices, shared storage access rules).
- **Container-Level**: Office-specific rules (e.g., IT office needs network admin access, HR office allows file edits).
- **Example**: Building sets employee ID (`runAsUser`) and shared storage group (`fsGroup`). IT office overrides ID (`runAsUser`), adds Wi-Fi control (`capabilities`), and locks files to read-only (`readOnlyRootFilesystem`).

## SELinux Volume Relabeling (Kubernetes v1.33, beta)
- **Default**: Recursively relabels volume files with SELinux labels.
- **Optimization**: Uses mount option `-o context=<label>` for speed if:
  - `SELinuxMount` feature gate is enabled.
  - Volume is `ReadWriteOncePod` or CSI driver supports `seLinuxMount: true`.
  - Pod has `seLinuxOptions` set.
- **seLinuxChangePolicy**:
  - `MountOption` (default): Uses mount option for relabeling.
  - `Recursive`: Falls back to recursive relabeling for shared volumes with different labels.
- **SELinuxWarningController**: Detects conflicting SELinux labels on shared volumes, emits warnings.

## Volume Ownership (fsGroup)
- **Default**: Kubernetes recursively changes volume ownership/permissions to match `fsGroup`.
- **fsGroupChangePolicy**:
  - `OnRootMismatch`: Changes only if root directory mismatches.
  - `Always`: Changes on every mount.
- **CSI Drivers**: If `VOLUME_MOUNT_GROUP` is supported, CSI driver handles `fsGroup` (bypasses `fsGroupChangePolicy`).

## Managing /proc Filesystem (Kubernetes v1.33, beta)
- **Default**: Masks paths like `/proc/asound`, makes others like `/proc/sys` read-only.
- **procMount**:
  - `Unmasked`: Allows full access to `/proc` and `/sys/firmware` (requires `hostUsers: false`).
  - Used for containers needing full `/proc` access (e.g., nested containers).

## Cleanup
```bash
kubectl delete pod security-context-demo
kubectl delete pod security-context-demo-2
kubectl delete pod security-context-demo-3
kubectl delete pod security-context-demo-4
```

## Key Takeaways
- Use pod-level `securityContext` for baseline settings (e.g., `runAsUser`, `fsGroup`).
- Use container-level `securityContext` for specific overrides (e.g., `capabilities`, `readOnlyRootFilesystem`).
- Enable feature gates like `SELinuxMount` or `SupplementalGroupsPolicy` for advanced control.
- Regularly clean up test pods to avoid clutter.

## References
- [PodSecurityContext](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#podsecuritycontext-v1-core)
- [SecurityContext](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#securitycontext-v1-core)
- [Ownership Management Design](https://kubernetes.io/docs/concepts/storage/volumes/#ownership-management)
