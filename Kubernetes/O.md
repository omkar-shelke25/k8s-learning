Below are example `curl` commands to test the microservices application (`User Service`, `Order Service`, `Payment Service`) running locally at `http://localhost:8001`, `http://localhost:8002`, and `http://localhost:8003`. These commands demonstrate key API operations: health checks, creating a user, creating an order, and creating a payment. Each command is designed to work with the application setup from your previous context (`Simple-Microservice-App`).

---

### Example `curl` Commands

1. **Health Check - User Service**
   ```bash
   curl -X GET http://localhost:8001/health
   ```
   - **Expected**: `{"status":"enabled"}`
   ```
   {"status":"healthy"}
 
   ```

2. **Create User - User Service**
   ```bash
   curl -X POST http://10.97.199.253:8001/users/ -H "Content-Type: application/json" -d '{"name":"John Doe","email":"john@example.com"}'
   ```
   **Expected**: `{"_id":"user_id","name":"John Doe","email":"john@example.com"}` (replace `user_id` with actual ID)
   ```json
   {
     "_id": "<user_id>",
     "name": "John Doe",
     "email": "john@example.com"
   }
   ```

3. **Health Check - Order Service**
   ```bash
   curl -X GET http://localhost:8002/health
   ```
   - **Expected**: `{"status":"enabled"}`
   ```
   {"status":"healthy"}
   ```

4. **Create Order - Order Service**
   - Use the `<user_id>` from the user creation response above.
   ```bash
   curl -X POST http://10.109.15.149:8002/orders/ -H "Content-Type: application/json" -d '{"user_id":"684a4bda16dda24edb3a9b91","product":"Laptop","amount":999.99}'
   ```
   - **Expected**: `{"_id":"order_id","user_id":"user_id":"...","product":"Laptop","amount":999.99}`
     ```json
     {
       "_id": "<order_id>",
       "user_id": "<user_id>",
       "product": "Laptop",
       "amount": 999.99
     }
     ```

5. **Health Check - Payment Service**
   ```bash
   curl -X GET http://localhost:8003/health
   ```
   - **Expected**: `{"status":"enabled"}`
   ```
   {"status":"healthy"}
   ```

6. **Create Payment - Payment Service**
   - Use the `<order_id>` from the order creation response above.
   ```bash
   curl -X POST http://payment-microservice-service.default.svc.cluster.local:8003/payments/ -H "Content-Type: application/json" -d '{"order_id":"684a4c22628bab847bc7cd9f","amount":999.99,"status":"pending"}'
   ```
   **Expected**: `{"_id":"payment_id","order_id":"...","amount":999.99,"status":"pending"}`
   ```json
   {
     "_id": "<payment_id>",
     "order_id": "<order_id>",
     "amount": 999.99,
     "status": "pending"
   }
   ```

---

### Notes
- **Prerequisites**: Ensure the application is running locally (e.g., using `run_local.sh` or `docker-compose up` from previous responses).
- **Sequence**: Run commands in order, as orders require a `user_id`, and payments require an `order_id`.
- **Error Handling**: If a command fails, check the response or logs:
  ```bash
  cat ~/Simple-Microservice-App/user-service/user-service.log
  docker-compose logs user-service
  ```
- **Port Conflicts**: Ensure ports `8001`, `8002`, `8003`, and `27017` are free:
  ```bash
  sudo fuser -k 8001/tcp 8002/tcp 8003/tcp 27017/tcp
  ```

---

### Example Workflow
1. Check User Service health:
   ```bash
   curl -X GET http://localhost:8001/health
   ```

2. Create a user and capture `"_id"` (e.g., `user_id=123e4567e89b12d3a456426614174000`):
   ```bash
   curl -X POST http://localhost:8001/users/ -H "Content-Type: application/json" -d '{"name":"John Doe","email":"john@example.com"}'
   ```

3. Create an order using the `user_id`:
   ```bash
   curl -X POST http://localhost:8002/orders/ -H "Content-Type: application/json" -d '{"user_id":"123e4567e89b12d3a456426614174000","product":"Laptop","amount":999.99}'
   ```

4. Create a payment using the `order_id` from the previous response:
   ```bash
   curl -X POST http://localhost:8003/payments/ -H "Content-Type: application/json" -d '{"order_id":"456e7890e12b23c4b567d890123456789","amount":999.99,"status":"pending"}'
   ```

If you need more `curl` examples or encounter errors, share the output for debugging assistance.
