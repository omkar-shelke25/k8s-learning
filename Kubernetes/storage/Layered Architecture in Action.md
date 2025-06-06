### Example: Docker Data Storage and Layered Architecture in Action

Let’s walk through a practical example to understand how Docker stores data and manages its layered architecture. We’ll create a simple Docker image, run a container, and explore how Docker stores the data on the host system.

---

#### **Step 1: Create a Simple Dockerfile**
We’ll create a `Dockerfile` that builds an image with a few layers.

```dockerfile
# Dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl
COPY app.py /app/
CMD ["python3", "/app/app.py"]
```

- **Layer 1**: Base image (`ubuntu:20.04`).
- **Layer 2**: Installs `curl` using `apt-get`.
- **Layer 3**: Copies a file (`app.py`) into the `/app/` directory.
- **Layer 4**: Sets the default command to run `app.py`.

---

#### **Step 2: Build the Docker Image**
Run the following command to build the Docker image:

```bash
docker build -t my-app .
```

- Docker will execute each instruction in the `Dockerfile` and create a new layer for each step.
- The final image (`my-app`) will consist of all these layers stacked together.

---

#### **Step 3: Run a Container**
Start a container from the `my-app` image:

```bash
docker run -d --name my-container my-app
```

- Docker will create a writable layer on top of the image layers for this container.
- Any changes made during the container’s runtime (e.g., creating new files, modifying existing files) will be stored in this writable layer.

---

#### **Step 4: Explore Docker’s Data Storage**
Now, let’s explore how Docker stores the data for the image and container.

---

##### **1. Image Layers**
- Docker stores image layers in `/var/lib/docker/image/<storage-driver>/layerdb`.
- Each layer has a unique ID and is stored as a directory.
- Use the following command to inspect the image layers:

```bash
docker history my-app
```

Output:
```
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
<layer-3-id>   10 seconds ago   CMD ["python3" "/app/app.py"]                   0B        Build layer 3
<layer-2-id>   15 seconds ago   COPY app.py /app/                               1kB       Build layer 2
<layer-1-id>   20 seconds ago   RUN /bin/sh -c apt-get update && apt-get inst…  50MB      Build layer 1
<base-image>   2 weeks ago      /bin/sh -c #(nop)  CMD ["bash"]                 0B        Base image (ubuntu:20.04)
```

- Each layer corresponds to an instruction in the `Dockerfile`.

---

##### **2. Container Data**
- Docker stores container-specific data in `/var/lib/docker/containers/<container-id>`.
- Use the following command to find the container ID:

```bash
docker ps -a
```

- Navigate to the container’s directory:

```bash
cd /var/lib/docker/containers/<container-id>
```

- Key files in this directory:
  - `config.v2.json`: Configuration for the container.
  - `hostname`: Hostname of the container.
  - `hosts`: DNS resolution file.
  - `logs/`: Logs generated by the container.
  - `mounts/`: Information about mounted volumes and bind mounts.

---

##### **3. Volumes**
- If you create a volume for the container, it will be stored in `/var/lib/docker/volumes/<volume-name>`.
- Example: Create a volume and attach it to the container:

```bash
docker volume create my-volume
docker run -d --name my-container -v my-volume:/data my-app
```

- The volume data will be stored in `/var/lib/docker/volumes/my-volume/_data`.

---

#### **Step 5: Modify the Container**
- Let’s make some changes inside the running container to see how Docker handles the writable layer.

1. Exec into the container:

```bash
docker exec -it my-container bash
```

2. Create a new file in the container:

```bash
echo "Hello, Docker!" > /app/test.txt
```

3. Exit the container.

- The new file (`test.txt`) is stored in the container’s writable layer.

---

#### **Step 6: Inspect the Writable Layer**
- The writable layer for the container is stored in `/var/lib/docker/overlay2/<container-id>/diff`.
- Navigate to the directory:

```bash
cd /var/lib/docker/overlay2/<container-id>/diff
```

- You’ll see the `test.txt` file created earlier.

---

#### **Step 7: Stop and Remove the Container**
- Stop the container:

```bash
docker stop my-container
```

- Remove the container:

```bash
docker rm my-container
```

- The writable layer for the container is deleted, but the image layers and volumes remain intact.

---

#### **Step 8: Clean Up**
- Remove the image:

```bash
docker rmi my-app
```

- Remove the volume (if no longer needed):

```bash
docker volume rm my-volume
```

---

#### **Summary of the Example**
- **Image Layers**: Docker creates immutable layers for each instruction in the `Dockerfile`.
- **Container Layer**: Docker adds a writable layer on top of the image layers for runtime changes.
- **Volumes**: Persistent data is stored in `/var/lib/docker/volumes/`.
- **Union Filesystem**: Docker uses a union filesystem (e.g., `overlay2`) to combine layers into a single filesystem.

---

#### **Diagram: Docker Layered Architecture in the Example**
```
+-------------------+
| Container Layer   |  (Writable layer for runtime changes, e.g., test.txt)
+-------------------+
| Image Layer 3     |  (CMD ["python3", "/app/app.py"])
+-------------------+
| Image Layer 2     |  (COPY app.py /app/)
+-------------------+
| Image Layer 1     |  (RUN apt-get update && apt-get install -y curl)
+-------------------+
| Base Image Layer  |  (ubuntu:20.04)
+-------------------+
```

---

This example demonstrates how Docker stores data and manages its layered architecture. By following these steps, you can see how Docker efficiently handles images, containers, and persistent data.
