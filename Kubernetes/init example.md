# Kubernetes Pod with Init Container Example

This YAML file defines a Kubernetes Pod with the following structure:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
spec:
  volumes:
    - name: shared-data
      emptyDir: {}
  initContainers:
    - name: init-container
      image: ubuntu
      command: ['sh', '-c', 'echo "initialized container configure"; mkdir -p /omkara/IT; echo "Hello World" > /omkara/main.py']
      volumeMounts:
        - name: shared-data
          mountPath: /omkara
  containers:
    - name: main-container
      image: nginx
      command: ['sh', '-c', 'cat /root/main.py; sleep 3600']
      volumeMounts:
        - name: shared-data
          mountPath: /root
```

### Explanation

#### Metadata
- `name: web`: Specifies the name of the Pod.

#### Volumes
- `shared-data`: An `emptyDir` volume is used to share data between the init container and the main container. This volume is created when the Pod starts and is empty initially.

#### Init Containers
- **Purpose**: Init containers run before the main container starts. They are typically used for setup tasks.
- **Details**:
  - `name: init-container`: The name of the init container.
  - `image: ubuntu`: The container image used.
  - `command`: Executes a shell script to:
    1. Print a message (`"initialized container configure"`).
    2. Create a directory `/omkara/IT`.
    3. Write the string `"Hello World"` to a file `/omkara/main.py`.
  - `volumeMounts`: Mounts the `shared-data` volume to `/omkara` inside the init container, allowing it to store the `main.py` file in the shared volume.

#### Main Container
- **Purpose**: The main application container that performs the primary function of the Pod.
- **Details**:
  - `name: main-container`: The name of the main container.
  - `image: nginx`: The container image used.
  - `command`: Executes a shell script to:
    1. Display the contents of the `main.py` file stored in `/root` (mapped from the shared volume).
    2. Keep the container running for 3600 seconds (`sleep 3600`).
  - `volumeMounts`: Mounts the `shared-data` volume to `/root`, allowing access to the file created by the init container.

### Workflow
1. The `init-container` runs first and performs the setup tasks.
2. The `main-container` starts after the `init-container` completes successfully.
3. The `main-container` reads the file created by the `init-container` and displays its content.

### Use Cases
- **Configuration Initialization**: Preparing configuration files or other resources before the main application starts.
- **Dependency Management**: Ensuring that prerequisites are in place for the main container.
- **Data Sharing**: Sharing files or data between containers in the same Pod using volumes.

### Notes
- The `emptyDir` volume ensures temporary storage for the lifetime of the Pod.
- If the `init-container` fails, the Pod will not proceed to start the main container.

### Run the Pod
To create the Pod, save this YAML to a file (e.g., `pod.yaml`) and apply it using:
```bash
kubectl apply -f pod.yaml
