
# 🧠 **Kubernetes & Linux: cgroups, CPU Throttling, and OOM Killer (In-depth Notes)**

---

## 🔹 **1. What are cgroups?**

### 📘 Definition:

**cgroups (Control Groups)** are a **Linux kernel feature** that allows the system to **allocate, prioritize, deny, or account** resource usage (CPU, memory, I/O, network) among groups of processes.

Every container in Kubernetes runs inside a **namespace** and a **cgroup**.

* **Namespace** → isolation (what a process can *see*).
* **cgroup** → limitation (how much resource a process can *use*).

Kubernetes uses **cgroups** to enforce the values defined under `resources.limits` and `resources.requests` in Pod specs.

---

## ⚙️ **2. Kubernetes Resource Management via cgroups**

Each container in Kubernetes can define:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "256Mi"
  limits:
    cpu: "1"
    memory: "512Mi"
```

| Field        | Meaning                                                                      |
| ------------ | ---------------------------------------------------------------------------- |
| **requests** | Minimum guaranteed resources for scheduling. Used by the **kube-scheduler**. |
| **limits**   | Maximum allowed resource usage. Enforced by **Linux cgroups**.               |

---

## 🔸 **3. Memory Management in Depth (OOM Killer)**

### 🧩 How It Works:

When a container’s memory usage exceeds its limit, the **Linux kernel OOM (Out Of Memory) killer** is triggered by the **cgroup memory subsystem**.

* Each container’s processes are confined within a memory limit.
* Once it tries to allocate memory beyond this limit → kernel denies allocation.
* Kernel identifies the most memory-hungry process and kills it.

In Kubernetes, this appears as:

```bash
kubectl describe pod <pod-name>
# ...
State:          Terminated
Reason:         OOMKilled
Exit Code:      137
```

---

### ⚠️ **Why OOMKill Happens**

1. Container tries to allocate more memory than its limit.
2. Memory cannot be "throttled" like CPU — the kernel must free memory immediately.
3. The kernel kills a process (inside the container).
4. The Pod may restart (depending on `restartPolicy`).

---

### 🧰 **Practical Example: OOMKill Demonstration**

Create a Pod that intentionally consumes too much memory.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-oom-demo
spec:
  containers:
  - name: memory-test
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "600M", "--vm-hang", "1"]
    resources:
      limits:
        memory: "200Mi"
      requests:
        memory: "100Mi"
```

**Explanation:**

* The container tries to allocate **600MB** memory.
* The cgroup limit is **200MB**.
* Result → The process is **OOMKilled**.

Check result:

```bash
kubectl get pod memory-oom-demo
kubectl describe pod memory-oom-demo | grep -A5 State
```

Expected:

```
State:          Terminated
Reason:         OOMKilled
Exit Code:      137
```

✅ **Observation:** Pod restarts automatically if restartPolicy = Always.

---

## 🔸 **4. CPU Management in Depth (Throttling)**

### 🧩 How It Works:

CPU usage is controlled by the **CPU cgroup controller** using two parameters:

* `cpu.cfs_quota_us`
* `cpu.cfs_period_us`

Default period = 100,000 µs (100ms).

If:

```
cpu.cfs_quota_us = 100000
cpu.cfs_period_us = 100000
```

→ Container gets **1 full CPU core** every 100ms.

If:

```
cpu.cfs_quota_us = 50000
cpu.cfs_period_us = 100000
```

→ Container gets **0.5 CPU core** → effectively throttled.

The process can still execute, but only for half the CPU time → slows down.

---

### 🧠 **Key Point:**

> CPU overuse = throttling (delay, slower execution)
> Memory overuse = OOMKill (process termination)

CPU can be **shared** and **delayed**, but memory cannot.

---

### 🧰 **Practical Example: CPU Throttling Demonstration**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-throttle-demo
spec:
  containers:
  - name: cpu-test
    image: vish/stress
    args:
      - -cpus
      - "2"
    resources:
      limits:
        cpu: "1"
      requests:
        cpu: "500m"
```

**Explanation:**

* The container tries to use 2 CPUs.
* The cgroup limit allows only 1 CPU.
* The kernel throttles CPU usage using the **CFS scheduler**.

Run the pod and check CPU throttling:

```bash
kubectl top pod cpu-throttle-demo
```

You’ll see **CPU usage capped around 1000m (1 core)** even though the process tries to use 2.

To view throttling metrics (on nodes with metrics-server or cAdvisor):

```bash
cat /sys/fs/cgroup/cpu,cpuacct/kubepods/.../cpu.stat
# Look for "nr_throttled" and "throttled_time"
```

These counters show **how many times** and **for how long** CPU throttling occurred.

---

## 📊 **5. Comparison: Memory vs CPU Behavior**

| Resource     | Behavior                   | Enforced By     | When Exceeded                   | Pod Effect                 |
| ------------ | -------------------------- | --------------- | ------------------------------- | -------------------------- |
| **Memory**   | Hard limit                 | memory cgroup   | Kernel cannot allocate more RAM | Process killed (OOMKilled) |
| **CPU**      | Soft limit                 | cpu cgroup      | Exceeds quota in a period       | Process slowed (throttled) |
| **Disk I/O** | Optional                   | blkio cgroup    | I/O operations > quota          | Slower disk reads/writes   |
| **Network**  | Optional (with tc or eBPF) | traffic control | Bandwidth exceeded              | Packet delay/drop          |

---

## 📱 **6. Real-World Analogy (Mobile CPU Example)**

| Concept               | Real Device Example | Kubernetes Equivalent   |
| --------------------- | ------------------- | ----------------------- |
| iPhone (A17 chip)     | Powerful CPU        | Pod with high CPU limit |
| Android (budget chip) | Moderate CPU        | Pod with low CPU limit  |
| Low RAM App Crash     | Insufficient memory | OOMKilled Pod           |
| Low CPU Device        | App runs slowly     | CPU throttled Pod       |

🧠 **Meaning:**

> “CPU shortage slows down tasks but doesn’t kill them.
> Memory shortage kills the process.”

---

## ⚙️ **7. Observing Resource Enforcement**

You can see how cgroups are applied under the hood.

1. Find the container ID:

   ```bash
   crictl ps
   ```

2. Enter the cgroup directory:

   ```bash
   cd /sys/fs/cgroup/
   ```

3. Check CPU and memory values:

   ```bash
   cat memory.max
   cat cpu.max
   ```

4. You’ll see Kubernetes limits translated into actual cgroup settings.

---

## 💡 **8. Best Practices for Resource Limits**

| Scenario             | Recommendation                                                      |
| -------------------- | ------------------------------------------------------------------- |
| Avoid OOMKilled      | Set realistic `memory.limits` slightly above `requests`.            |
| Avoid CPU starvation | Give `requests` close to `limits` if performance-critical.          |
| Monitoring           | Use `kubectl top`, `cAdvisor`, or Prometheus to monitor throttling. |
| Burstable workloads  | Lower requests, higher limits.                                      |
| Guaranteed workloads | Requests = Limits.                                                  |

---

## 🧾 **9. Summary: Key Differences**

| Feature             | Memory          | CPU                |
| ------------------- | --------------- | ------------------ |
| Controller          | `memory` cgroup | `cpu` cgroup       |
| Can be throttled?   | ❌ No            | ✅ Yes              |
| Killed if exceeded? | ✅ Yes (OOMKill) | ❌ No               |
| Scheduler impact    | High            | Moderate           |
| Type of limit       | Hard            | Soft (shared time) |
| Kernel mechanism    | OOM Killer      | CFS Quota/Period   |

---

## 🧩 **10. Verification Commands Summary**

| Purpose               | Command                                       |
| --------------------- | --------------------------------------------- |
| View Pod status       | `kubectl describe pod <name>`                 |
| Check OOMKill         | `kubectl get pod -o wide` + describe          |
| Check CPU usage       | `kubectl top pod <name>`                      |
| Check node throttling | `cat /sys/fs/cgroup/cpu,cpuacct/.../cpu.stat` |
| Check memory limit    | `cat /sys/fs/cgroup/memory/.../memory.max`    |

---

## ✅ **Final Takeaways**

1. **cgroups** are Linux mechanisms controlling process resources.
2. **Kubernetes** leverages them to enforce Pod resource limits.
3. **Memory**: non-shareable, causes OOMKill when exceeded.
4. **CPU**: shareable, throttled when exceeded (no killing).
5. Proper resource planning avoids throttling and OOM kills.
6. Always monitor using `kubectl top` and cAdvisor metrics.


