
# Code :: PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-log  # Name of the PersistentVolume
spec:
  capacity:
    storage: 100Mi  # The storage capacity of the PV (100 MiB)
  accessModes:
    - ReadWriteMany  # Access mode: Allows multiple nodes to read/write to the volume
  persistentVolumeReclaimPolicy: Retain  # Retain the volume even after the PVC is deleted
  hostPath:
    path: /pv/log  # Path on the host machine where the volume is stored
    type: Directory  # Type of the hostPath (Directory in this case)
```
## Code :: PersistentVolumeClaim
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-log-1
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Mi
```


### Binding Criteria:
1. **Storage Size**: The PVC requests 50Mi of storage, and the PV offers 100Mi. Since the PVC's request is less than or equal to the PV's capacity, the size requirement is satisfied.
2. **Access Modes**: Both the PV and PVC specify `ReadWriteMany` as the access mode, which matches.
3. **Volume Mode**: If specified, the volume mode (filesystem or block) must match. In this case, it is not explicitly specified, so it defaults to filesystem.
4. **Storage Class**: If a storage class is specified in the PVC, it must match the storage class of the PV. In this case, neither the PV nor the PVC specifies a storage class, so they are considered a match.
5. **Selector and Label Matching**: If the PVC specifies selector and label requirements, the PV must match those labels. In this case, no selectors or labels are specified, so this criterion is automatically satisfied.

### Automatic Binding:
Since the PVC (`claim-log-1`) does not explicitly reference the PV (`pv-log`), Kubernetes will automatically bind the PVC to the PV if the above criteria are met. In your case, the PVC will be bound to the PV because:
- The PVC's storage request (50Mi) is less than or equal to the PV's capacity (100Mi).
- The access modes (`ReadWriteMany`) match.
- No storage class or selectors are specified, so they are considered compatible.

### Verification:
After applying these YAML files, you can verify the binding by running the following command:
```bash
kubectl get pv pv-log
```
You should see that the `STATUS` of the PV is `Bound`, and the `CLAIM` column will show `default/claim-log-1` (assuming the PVC is created in the `default` namespace).

Similarly, you can check the PVC status:
```bash
kubectl get pvc claim-log-1
```
The `STATUS` of the PVC should be `Bound`, and the `VOLUME` column will show `pv-log`.

### Manual Binding (Optional):
If you want to explicitly bind the PVC to a specific PV, you can add a `volumeName` field to the PVC specification:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-log-1
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Mi
  volumeName: pv-log  # Explicitly bind to this PV
```
This ensures that the PVC will only bind to the PV named `pv-log`, even if other PVs meet the criteria.

### Applying the YAML Files:
To apply these configurations, use the following commands:
```bash
kubectl apply -f pv-log.yaml
kubectl apply -f pvc-log.yaml
```

After applying, Kubernetes will automatically bind the PVC to the PV if the criteria are met.
