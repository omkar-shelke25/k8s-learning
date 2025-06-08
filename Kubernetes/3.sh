#!/bin/bash

# Script to deploy MongoDB Community Operator, MongoDB Replica Set, and Mongo Express on Kubernetes
# Uses MongoDB 8.0, local-path storage class, and Mongo Express latest

# Configuration
NAMESPACE="mongodb"
OPERATOR_CHART="mongodb/community-operator"
MONGODB_VERSION="8.0.0"
REPLICA_SET_NAME="mongo-rs"
ADMIN_USER="admin"
ADMIN_PASSWORD="securepassword"
MONGO_EXPRESS_PORT="8081"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to check command existence
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is required but not installed. Please install it and try again.${NC}"
        exit 1
    fi
}

# Function to check if a resource exists
check_resource() {
    kubectl get "$1" "$2" -n "$NAMESPACE" &> /dev/null
    return $?
}

# Function to wait for pods to be ready
wait_for_pods() {
    local label=$1
    local timeout=300
    local start_time=$(date +%s)
    echo "Waiting for pods with label $label to be ready..."
    while true; do
        if kubectl get pods -n "$NAMESPACE" -l "$label" --no-headers 2>/dev/null | grep -v "Running" &> /dev/null; then
            sleep 5
            current_time=$(date +%s)
            if [ $((current_time - start_time)) -gt $timeout ]; then
                echo -e "${RED}Timeout waiting for pods to be ready.${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}Pods with label $label are ready.${NC}"
            break
        fi
    done
}

# Step 0: Validate prerequisites
echo "Checking prerequisites..."
check_command kubectl
check_command helm

# Verify Kubernetes cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Kubernetes cluster is not accessible. Please ensure your cluster is running and kubectl is configured.${NC}"
    exit 1
fi

# Step 1: Create namespace
echo "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" || echo "Namespace $NAMESPACE already exists."

# Step 2: Install MongoDB Community Operator
echo "Installing MongoDB Community Operator..."
helm repo add mongodb https://mongodb.github.io/helm-charts || true
helm repo update
helm upgrade --install community-operator "$OPERATOR_CHART" --namespace "$NAMESPACE" || {
    echo -e "${RED}Failed to install MongoDB Community Operator.${NC}"
    exit 1
}

# Wait for operator to be ready
wait_for_pods "app.kubernetes.io/name=community-operator"

# Step 3: Configure local-path storage class
echo "Checking local-path storage class..."
if ! kubectl get storageclass local-path &> /dev/null; then
    echo "Deploying local-path provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml || {
        echo -e "${RED}Failed to deploy local-path provisioner.${NC}"
        exit 1
    }
    sleep 10 # Allow provisioner to initialize
fi

# Step 4: Create MongoDB admin secret
echo "Creating MongoDB admin secret..."
cat <<EOF | kubectl apply -f - -n "$NAMESPACE"
apiVersion: v1
kind: Secret
metadata:
  name: mongo-admin
type: Opaque
stringData:
  user: $ADMIN_USER
  password: $ADMIN_PASSWORD
EOF

# Step 5: Deploy MongoDB Replica Set
echo "Deploying MongoDB Replica Set..."
cat <<EOF | kubectl apply -f - -n "$NAMESPACE"
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: $REPLICA_SET_NAME
spec:
  members: 3
  type: ReplicaSet
  version: "$MONGODB_VERSION"
  persistent: true
  storage:
    db:
      storageClass: local-path
      size: 2Gi
  security:
    authentication:
      modes: ["SCRAM"]
    users:
      - name: $ADMIN_USER
        db: admin
        passwordSecretRef:
          name: mongo-admin
        roles:
          - name: clusterAdmin
            db: admin
          - name: userAdminAnyDatabase
            db: admin
        scramCredentialsSecretName: admin-scram
  additionalMongodConfig:
    storage.wiredTiger.engineConfig.journalCompressor: zlib
EOF

# Wait for MongoDB pods to be ready
wait_for_pods "app.kubernetes.io/name=$REPLICA_SET_NAME"

# Verify MongoDB status
echo "Verifying MongoDB Replica Set status..."
if ! kubectl get mongodbcommunity "$REPLICA_SET_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' | grep "Running" &> /dev/null; then
    echo -e "${RED}MongoDB Replica Set is not running. Check logs with 'kubectl logs -l app.kubernetes.io/name=$REPLICA_SET_NAME -n $NAMESPACE'.${NC}"
    exit 1
fi
echo -e "${GREEN}MongoDB Replica Set is running.${NC}"

# Step 6: Deploy Mongo Express
echo "Deploying Mongo Express..."
cat <<EOF | kubectl apply -f - -n "$NAMESPACE"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo-express
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo-express
  template:
    metadata:
      labels:
        app: mongo-express
    spec:
      containers:
      - name: mongo-express
        image: mongo-express:latest
        ports:
        - containerPort: $MONGO_EXPRESS_PORT
        env:
        - name: ME_CONFIG_MONGODB_URL
          value: "mongodb://$ADMIN_USER:$ADMIN_PASSWORD@$REPLICA_SET_NAME-svc.$NAMESPACE.svc.cluster.local:27017/?replicaSet=$REPLICA_SET_NAME&authSource=admin"
        - name: ME_CONFIG_BASICAUTH_ENABLED
          value: "false"
---
apiVersion: v1
kind: Service
metadata:
  name: mongo-express-svc
spec:
  selector:
    app: mongo-express
  ports:
  - protocol: TCP
    port: $MONGO_EXPRESS_PORT
    targetPort: $MONGO_EXPRESS_PORT
  type: ClusterIP
EOF

# Wait for Mongo Express to be ready
wait_for_pods "app=mongo-express"

# Step 7: Provide access instructions
echo -e "${GREEN}Setup complete!${NC}"
echo "To access Mongo Express, run:"
echo "  kubectl port-forward svc/mongo-express-svc $MONGO_EXPRESS_PORT:$MONGO_EXPRESS_PORT -n $NAMESPACE"
echo "Then open http://localhost:$MONGO_EXPRESS_PORT in your browser."
echo
echo "To connect to MongoDB locally, run:"
echo "  kubectl port-forward svc/$REPLICA_SET_NAME-svc 27017:27017 -n $NAMESPACE"
echo "Then use this connection string:"
echo "  mongodb://$ADMIN_USER:$ADMIN_PASSWORD@localhost:27017/?replicaSet=$REPLICA_SET_NAME&authSource=admin"
echo
echo "To verify data persistence, create a test document in Mongo Express or mongosh, then restart MongoDB pods:"
echo "  kubectl delete pod -l app.kubernetes.io/name=$REPLICA_SET_NAME -n $NAMESPACE"
echo "Check if the document persists after pods restart."
