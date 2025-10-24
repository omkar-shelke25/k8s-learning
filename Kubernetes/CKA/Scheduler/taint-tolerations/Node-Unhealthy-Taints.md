
🧩 **Node Unhealthy Taints and Automatic Pod Eviction (NoExecute)**

This is one of the most *misunderstood yet highly testable* scheduling mechanisms in Kubernetes —
so let’s break it down **step-by-step**, from architecture to internal logic, with real examples, control flow, and YAML references.

---

# 🌍 **Deep Notes — Node Becomes Unhealthy & Automatic Taints**

---

## 🧠 1. **Core Concept**

When a **Kubernetes Node** becomes **unreachable or unhealthy**,
the **Node Controller** (inside the control plane) automatically applies **system taints**
to inform the scheduler and controllers that **this node should not host active workloads**.

These taints trigger the **pod eviction process**, ensuring Pods on that node are
**gracefully rescheduled** to healthy nodes — without manual intervention.

---

## ⚙️ 2. **Automatic Taints Added by the Node Controller**

The Node Controller continuously monitors each Node’s `NodeCondition` status (`Ready`, `Reachable`, etc.).
When unhealthy conditions persist, the following **automatic taints** are applied:

| Node Condition   | Automatic Taint                                 | Effect                   | Added By        | Purpose                    |
| ---------------- | ----------------------------------------------- | ------------------------ | --------------- | -------------------------- |
| `NotReady`       | `node.kubernetes.io/not-ready:NoExecute`        | Evict non-tolerant Pods  | Node Controller | Node can’t report status   |
| `Unreachable`    | `node.kubernetes.io/unreachable:NoExecute`      | Evict non-tolerant Pods  | Node Controller | Control plane lost contact |
| `MemoryPressure` | `node.kubernetes.io/memory-pressure:NoSchedule` | Stop scheduling new Pods | Kubelet         | Node under memory stress   |
| `DiskPressure`   | `node.kubernetes.io/disk-pressure:NoSchedule`   | Stop new Pods            | Kubelet         | Disk almost full           |
| `PIDPressure`    | `node.kubernetes.io/pid-pressure:NoSchedule`    | Stop new Pods            | Kubelet         | Too many processes         |

👉 The ones relevant to **node failure and eviction** are the first two — both use **`NoExecute`**.

---

## 🧩 3. **Effect Types Recap**

| Effect             | Meaning                                                                   | Applies To    |
| ------------------ | ------------------------------------------------------------------------- | ------------- |
| `NoSchedule`       | Scheduler will **not place** new Pods on the node                         | New Pods      |
| `PreferNoSchedule` | Scheduler tries to avoid node, but not strict                             | New Pods      |
| `NoExecute`        | Pods **already running** are **evicted** if they can’t tolerate the taint | Existing Pods |

✅ So `NoExecute` is special — it **affects existing Pods**, not just future ones.

---

## 🧱 4. **Default Pod Tolerations (System-Added)**

Most Pods created by controllers (Deployments, ReplicaSets, DaemonSets) automatically get these tolerations:

```yaml
tolerations:
- key: "node.kubernetes.io/not-ready"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300

- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300
```

### 💬 Meaning:

> “If the node becomes `NotReady` or `Unreachable`, I can **stay for 300 seconds** (5 minutes).
> If the node is still unhealthy after that, **evict me**.”

### Why `operator: Exists`?

Because these taints only have a **key**, not a `key=value` pair.
Pods tolerate the *presence* of the key, regardless of any value.

---

## ⏳ 5. **Eviction Flow — Step by Step**

Here’s what happens when a Node goes bad 👇

| Step | Component                   | Action                                                                      |
| ---- | --------------------------- | --------------------------------------------------------------------------- |
| 1️⃣  | **Node Controller**         | Detects node is NotReady/Unreachable after a grace period (default: 40s–1m) |
| 2️⃣  | **Node Controller**         | Applies taint `node.kubernetes.io/not-ready:NoExecute`                      |
| 3️⃣  | **Kube Controller Manager** | Checks all Pods on that node                                                |
| 4️⃣  |                             | Evicts Pods **without toleration** immediately                              |
| 5️⃣  |                             | Waits `tolerationSeconds` for Pods with toleration                          |
| 6️⃣  | **Scheduler**               | Reschedules evicted Pods to healthy nodes                                   |
| 7️⃣  | **Node Recovers**           | Taint automatically removed, node usable again                              |

---

## 📊 6. **Visual Timeline**

```
🟢 Node Healthy → Pod Running
     ↓
🔴 Node NotReady → Taint: node.kubernetes.io/not-ready:NoExecute
     ↓
⏳ Pod Tolerates for 300s (default)
     ↓
💣 Node still Unreachable → Pod Evicted
     ↓
⚙️ Scheduler reschedules Pod on another node
```

---

## 🧭 7. **Real Example (Simulation)**

### Step 1 — Create a Pod

```bash
kubectl run demo --image=nginx
```

### Step 2 — Find its Node

```bash
kubectl get pod demo -o wide
```

### Step 3 — Manually Simulate Node Failure

```bash
kubectl taint nodes <node-name> node.kubernetes.io/not-ready=:NoExecute
```

### Step 4 — Watch Behavior

```bash
kubectl get pods -w
```

You’ll see:

```
demo   0/1   Terminating   0   10s
```

Then it gets recreated on another node.

### Step 5 — Recover Node

```bash
kubectl taint nodes <node-name> node.kubernetes.io/not-ready:NoExecute-
```

---

## 🧠 8. **Why This Matters (Design Goals)**

* Ensures **cluster self-healing** when nodes die.
* Avoids Pods staying stuck forever on dead nodes.
* Gives **grace period (tolerationSeconds)** so transient network glitches don’t cause unnecessary evictions.
* Keeps scheduling stable by only evicting if the problem persists.

---

## 🧩 9. **`tolerationSeconds` Behavior**

| Value             | Behavior                               |
| ----------------- | -------------------------------------- |
| **Not set**       | Pod stays indefinitely (never evicted) |
| **0**             | Pod evicted immediately                |
| **300 (default)** | Pod waits 5 minutes before eviction    |

You can modify this in your Pod spec to control eviction delay:

```yaml
tolerationSeconds: 600   # 10 minutes grace period
```

---

## 🔍 10. **Control Plane Components Involved**

| Component                                        | Role                                            |
| ------------------------------------------------ | ----------------------------------------------- |
| **Kubelet**                                      | Updates node status (`Ready`, `NotReady`, etc.) |
| **Node Controller (in kube-controller-manager)** | Applies taints and manages eviction logic       |
| **Scheduler**                                    | Places new Pods after eviction                  |
| **API Server**                                   | Updates taint and Pod status in etcd            |

---

## 🧩 11. **Observability Tips**

Check node taints:

```bash
kubectl describe node <node-name> | grep Taints
```

Check taint events:

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

Watch evictions:

```bash
kubectl get pods -A --field-selector=status.phase=Failed
```

---

## 🧠 12. **CKA Exam Insights**

You may get tasks like:

* “A node is marked NotReady. Find the taints applied and describe which Pods will stay or be evicted.”
* “Create a Pod that tolerates `node.kubernetes.io/unreachable` for 10 minutes.”
* “Remove automatic NoExecute taint to simulate node recovery.”

Remember these 3 golden rules:

| Concept                | Key Rule                                         |
| ---------------------- | ------------------------------------------------ |
| **Taint Added**        | Node unhealthy → system adds `NoExecute` taints  |
| **Pod Eviction Delay** | Controlled by `tolerationSeconds`                |
| **Taint Removal**      | Happens automatically when node is healthy again |

---

## 🧩 13. **Real-World Production Impact**

* Prevents Pods from being “ghost-running” on dead nodes.
* Keeps services highly available by shifting workloads automatically.
* Can be tuned for sensitive apps (e.g., databases) to wait longer before rescheduling.

---

## 📘 14. **In One Sentence**

> When a node fails, Kubernetes marks it tainted with `NoExecute`.
> Pods with tolerations stay for a while, others are evicted immediately —
> enabling **automatic, graceful self-healing** of workloads across healthy nodes.

---


