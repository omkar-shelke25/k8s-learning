#!/bin/bash

# Exit on error
set -e

# Define project directory
PROJECT_DIR="$HOME/Simple-Microservice-App"

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory $PROJECT_DIR does not exist. Please ensure project files are set up."
  exit 1
fi

# Step 1: Install Python 3.10 and pip
echo "Installing Python 3.10 and pip..."
sudo apt update
sudo apt install -y python3.10 python3.10-venv python3-pip
echo "Python installed."

# Step 2: Install MongoDB
echo "Installing MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod
echo "MongoDB installed and running."

# Step 3: Create .env files for local execution
echo "Creating .env files..."
cat > "$PROJECT_DIR/user-service/.env" << 'EOF'
PORT=8001
MONGODB_URI=mongodb://localhost:27017/user_db
EOF

cat > "$PROJECT_DIR/order-service/.env" << 'EOF'
PORT=8002
MONGODB_URI=mongodb://localhost:27017/order_db
USER_SERVICE_URL=http://localhost:8001
EOF

cat > "$PROJECT_DIR/payment-service/.env" << 'EOF'
PORT=8003
MONGODB_URI=mongodb://localhost:27017/payment_db
ORDER_SERVICE_URL=http://localhost:8002
EOF
echo ".env files created."

# Step 4: Set up virtual environments and install dependencies
for service in user-service order-service payment-service; do
  echo "Setting up $service..."
  cd "$PROJECT_DIR/$service"
  
  # Create virtual environment
  python3.10 -m venv venv
  
  # Activate virtual environment and install dependencies
  source venv/bin/activate
  if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
  else
    echo "Error: requirements.txt not found in $service"
    exit 1
  fi
  deactivate
  echo "$service setup complete."
done

# Step 5: Initialize MongoDB databases
echo "Initializing MongoDB databases..."
mongosh << 'EOF'
use user_db
db.createCollection("users")
use order_db
db.createCollection("orders")
use payment_db
db.createCollection("payments")
EOF
echo "MongoDB databases initialized."

# Step 6: Run services in the background
echo "Starting services..."
cd "$PROJECT_DIR/user-service"
source venv/bin/activate
nohup python main.py > user-service.log 2>&1 &
USER_PID=$!
deactivate

cd "$PROJECT_DIR/order-service"
source venv/bin/activate
nohup python main.py > order-service.log 2>&1 &
ORDER_PID=$!
deactivate

cd "$PROJECT_DIR/payment-service"
source venv/bin/activate
nohup python main.py > payment-service.log 2>&1 &
PAYMENT_PID=$!
deactivate

# Wait briefly to ensure services start
sleep 5

# Step 7: Check if services are running
echo "Checking service status..."
if ps -p $USER_PID > /dev/null; then
  echo "User Service is running (PID: $USER_PID)"
else
  echo "Error: User Service failed to start. Check $PROJECT_DIR/user-service/user-service.log"
  cat "$PROJECT_DIR/user-service/user-service.log"
  exit 1
fi

if ps -p $ORDER_PID > /dev/null; then
  echo "Order Service is running (PID: $ORDER_PID)"
else
  echo "Error: Order Service failed to start. Check $PROJECT_DIR/order-service/order-service.log"
  cat "$PROJECT_DIR/order-service/order-service.log"
  exit 1
fi

if ps -p $PAYMENT_PID > /dev/null; then
  echo "Payment Service is running (PID: $PAYMENT_PID)"
else
  echo "Error: Payment Service failed to start. Check $PROJECT_DIR/payment-service/payment-service.log"
  cat "$PROJECT_DIR/payment-service/payment-service.log"
  exit 1
fi

# Step 8: Display service URLs and instructions
echo "Application services are running at:"
echo "User Service: http://localhost:8001/health"
echo "Order Service: http://localhost:8002/health"
echo "Payment Service: http://localhost:8003/health"
echo "You can test the application using Postman."
echo "Logs are available in:"
echo "  $PROJECT_DIR/user-service/user-service.log"
echo "  $PROJECT_DIR/order-service/order-service.log"
echo "  $PROJECT_DIR/payment-service/payment-service.log"
echo "To stop the services, run:"
echo "  kill $USER_PID $ORDER_PID $PAYMENT_PID"
echo "Or stop MongoDB with: sudo systemctl stop mongod"
