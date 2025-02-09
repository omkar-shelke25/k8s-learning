### What is **UID**?

- **UID** stands for **User ID**.  
- In **Linux** (and Unix-like systems), every user is assigned a **unique number** called a **UID**.  
- The system uses this number to **identify** users, not their usernames.  

For example:
- `root` user has **UID 0** (this is the superuser with full permissions).
- Regular users typically have UIDs starting from **1000**.

---

### How Does UID Relate to a **Process**?

A **process** is any running program on your system (like a web server, a script, or an app).

When a process runs, it **inherits** the UID of the user who started it. The **UID controls what that process can and cannot do**.

- **If a process runs with UID 0 (root):** It has **full system permissions** (can modify any file, change settings, etc.).
- **If a process runs with a non-root UID (e.g., 1000):** It has **limited permissions**, usually restricted to that user's files and actions.

---

### Why Is This Important in **Kubernetes**?

By default, containers might run as **root** (UID 0), which is risky because:
1. **Security Risks**: If someone exploits the app, they might gain **full control** over the container or even the host system.
2. **Best Practice**: Running with a **non-root UID** restricts what processes inside the container can do, improving security.

When you use `runAsUser: 1000` in Kubernetes:
- You're telling Kubernetes: **“Run this app as a non-root user with UID 1000.”**
- This helps **isolate** and **secure** your app.

---

### Visual Example:

1. **Running as root (UID 0):**
   - Can delete system files. ❌ (Dangerous!)
   - Can access all other users' data.

2. **Running as UID 1000 (non-root):**
   - Can only access its own files. ✅ (Much safer)
   - Can't perform system-level actions.

---
