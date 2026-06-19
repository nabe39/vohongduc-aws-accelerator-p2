# Runbook: External Secrets Operator (ESO) Rotation Verification

This runbook outlines how to verify that the External Secrets Operator updates secrets dynamically, honors the rotation interval (< 60s), and updates the pod volumes without causing pod restarts.

## 1. Concepts

- **ExternalSecret `refreshInterval`**: Set to `10s` in `cloud/w10/lab/eso/external-secret.yaml` (well below the required 60s limit). This instructs the operator to sync the credentials from AWS Secrets Manager every 10 seconds.
- **Volume Mount vs Environment Variables**: By mounting the `k8s-db-secret` as a file volume in `rollout.yaml` (`/etc/secrets`), Kubernetes updates the files dynamically. If we used environment variables, we would need to recreate/restart the pods to load the new secret values.

## 2. Verification Procedure

### Step 2.1: Monitor current Pod status and restarts
Open a terminal and watch the pods in the `demo` namespace:
```bash
kubectl get pods -n demo -l app=api -w
```
Take note of the restart counts and creation times of the pods.

### Step 2.2: Update the secret in AWS Secrets Manager
Modify the secret `dev/app/mysql` value (e.g., change `password`) in your AWS console or using the AWS CLI:
```bash
aws secretsmanager put-secret-value --secret-id dev/app/mysql --secret-string '{"username":"dbuser","password":"newpassword"}' --region us-east-1
```

### Step 2.3: Verify Kubernetes Secret Update (< 60s)
Wait 10-20 seconds for the ESO controller to sync the secret. Retrieve the updated value in the cluster and decode it:
```bash
kubectl get secret k8s-db-secret -n demo -o jsonpath="{.data.database-password}" | base64 -d
```
Confirm that the password matches the newly updated value.

### Step 2.4: Verify Pod dynamic mount update (No Restart)
1. Check that the pods have **NOT** restarted (their restart count remains `0` or does not increase, and they are not in `Terminating`/`ContainerCreating` state).
2. Query the mounted secret inside one of the api pods:
   ```bash
   kubectl exec -it -n demo deploy/api -c api -- cat /etc/secrets/database-password
   ```
   Confirm that the updated password is visible in the container volume file.
   *(Note: Kubelet updates mounted secrets dynamically, though there may be a cache delay of up to 1 minute depending on kubelet settings. The pod does not restart during this update).*
