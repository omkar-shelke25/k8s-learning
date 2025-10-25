# Kubernetes & Linux: cgroups, CPU Throttling, and OOM Killer — In-depth Notes

> Detailed study notes with practical examples and a Mermaid diagram to visualize the flow.

---

## 1. Overview

**cgroups (Control Groups)** are a Linux kernel feature used to allocate, limit, prioritize, and account for resource usage (CPU, memory, I/O, etc.) among groups of processes. Kubernetes configures cgroups for each container to enforce `resources.limits` and `resources.requests` defined in Pod specs.

---

## 2. Core Concepts

* **Namespace**: process isolation (what the process can see).
* **cgroup**: resource limitation and accounting (how much resource the process may use).
* **requests**: scheduler hint (the amount of resource guaranteed for scheduling).
* **limits**: runtime enforcement via cgroups.

---

## 3. Memory (OOM Killer) — Detailed

**Behavior**

* Memory limits are enforced by the memory cgroup subsystem. Memory cannot be 'time-sliced' like CPU.
* When a process requests more memory than allowed, the kernel denies allocation and may invoke the Out Of Memory (OOM) killer.
* The kernel chooses a victim (usually the highest memory consumer) and kills it to free memory.

**Kubernetes Observables**

* Pod status will show `OOMKilled` and often exit code `137`.
* `kubectl describe pod <pod>` shows termination reason `OOMKilled`.

**Why OOMKill?**

* Memory must be available when requested. The kernel cannot delay allocations indefinitely; if memory is exhausted, it must free it.

**Practical OOM demo YAML**

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

**Expected outcome**: The container will try to allocate 600Mi while limit is 200Mi → kernel OOM kills the process. Pod shows `OOMKilled`.

---

## 4. CPU (CFS Throttling) — Detailed

**Mechanism**

* The CPU cgroup controller (CFS — Completely Fair Scheduler) uses `cpu.cfs_quota_us` and `cpu.cfs_period_us` to limit CPU consumption.

  * Default `cpu.cfs_period_us` = 100000 (100ms).
  * If `cpu.cfs_quota_us = 100000` and `cpu.cfs_period_us = 100000`, container gets 1 CPU core worth of time per 100ms.
  * If `cpu.cfs_quota_us = 50000` (period 100000), container gets 0.5 CPU core.

**Behavior**

* When a container exceeds its allowed quota in a period, scheduling simply delays its execution until the next period (throttling).
* The process is **not killed**; it experiences reduced throughput/latency — it runs slower.

**Practical CPU throttle demo YAML**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-throttle-demo
spec:
  containers:
  - name: cpu-test
    image: vish/stress
    args: ["-cpus", "2"]
    resources:
      limits:
        cpu: "1"
      requests:
        cpu: "500m"
```

**Expected outcome**: The container tries to use 2 CPUs; cgroup allows 1 CPU — the process will be throttled and observed as capped around `1000m` in `kubectl top`.

**Observability**

* Inspect cgroup stats on the node: `cat /sys/fs/cgroup/cpu,cpuacct/<path-to-cgroup>/cpu.stat`

  * Look for `nr_throttled` and `throttled_time` counters.
* Metrics-server, cAdvisor, and Prometheus exporters can show throttling events.

---

## 5. Comparison Table

| Resource |      Enforced by | When Exceeded                                    | Kernel Reaction               | Pod Effect                                   |
| -------- | ---------------: | ------------------------------------------------ | ----------------------------- | -------------------------------------------- |
| Memory   |    memory cgroup | Process requests allocation > limit              | OOM killer kills process      | Pod `OOMKilled`, restart according to policy |
| CPU      | cpu cgroup (CFS) | Process uses more CPU time than quota for period | Throttling (delays execution) | Pod runs slower, not killed                  |

---

## 6. Under-the-hood: How Kubernetes applies limits

* kubelet translates `resources.limits` into container runtime config and cgroup settings.
* container runtime (containerd/cri-o) sets up the cgroup for the container.
* On the node, examine `/sys/fs/cgroup/` and the specific controllers for actual applied values.

Example checks:

```bash
# list cgroups for pod/container (path varies by runtime and kubelet setup)
ls /sys/fs/cgroup/

# read memory limit for a cgroup
cat /sys/fs/cgroup/memory/.../memory.max

# read cpu limits
cat /sys/fs/cgroup/cpu,cpuacct/.../cpu.max
# or old-style
cat /sys/fs/cgroup/cpu/.../cpu.cfs_quota_us
cat /sys/fs/cgroup/cpu/.../cpu.cfs_period_us
```

---

## 7. Best Practices

* Set `requests` sensibly (scheduler reliance). Use `limits` to avoid noisy neighbor issues.
* For latency-sensitive workloads, keep `requests` close to `limits` (or set `Guaranteed` QoS by equalizing them).
* Monitor throttling (`throttled_time`) and memory pressure to adjust limits.
* Use Horizontal Pod Autoscaler (HPA) for CPU-bound workloads to scale horizontally rather than simply raising limits.

---

## 8. Commands Quick Reference

* Pod status & OOM: `kubectl describe pod <pod>`
* Pod metrics: `kubectl top pod <pod>`
* Node cgroup checks: `cat /sys/fs/cgroup/.../cpu.stat` and `memory.max`
* Container runtime container list: `crictl ps` (or `docker ps` on older setups)

---

## 9. Mermaid Diagram

```mermaid
flowchart LR
  Client[User / External Request] -->|creates Pod| KubeAPI[Kubernetes API]
  KubeAPI --> kubelet[Kubelet]
  kubelet --> CRI[Container Runtime (containerd/cri-o)]
  CRI --> CGroup[cgroup for container]

  CGroup --> CPU[cpu subsystem (CFS quota/period)]
  CGroup --> MEM[memory subsystem (memory.limit)]

  CPU --> Throttle[Throttling — process delayed, runs slower]
  MEM --> OOM[OOM Killer — process terminated]

  Throttle --> Process[Container Process — continues but slower]
  OOM --> ProcessKilled[Process Killed → Pod shows OOMKilled]

  style OOM fill:#ffdddd,stroke:#ff0000
  style Throttle fill:#fff3cd,stroke:#f39c12
```

---

## 10. Extra Notes for Exams

* Remember `requests` vs `limits` semantics and QoS classes: `Guaranteed`, `Burstable`, `BestEffort`.
* `Guaranteed` QoS (requests==limits) lowers chance of eviction.
* OOM events show `Exit Code 137` usually — memorize this for quick exam identification.
* To intentionally trigger throttling/OOM in a lab, use `stress` or small custom programs that allocate memory or spin CPU.

---

