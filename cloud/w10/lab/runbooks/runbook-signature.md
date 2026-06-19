# Runbook: Image Signing & Verification with Cosign

This runbook outlines how to generate key pairs, sign images, verify signatures, and troubleshoot admission controller rejections in the cluster.

## 1. Key Generation

If `cosign` CLI is not installed locally, you can run it via Docker:

```bash
# Generate key pair in the current directory
docker run --rm -it -v "${PWD}:/keys" -w /keys ghcr.io/sigstore/cosign/cosign:v2.2.4 generate-key-pair
```

This will produce:
- `cosign.key`: The encrypted private key. **DO NOT COMMIT THIS FILE.**
- `cosign.pub`: The public key. **COMMIT THIS FILE** to `cloud/w10/lab/signing/cosign.pub`.

## 2. GitHub Actions Secrets Configuration

Add the following Secrets to your GitHub Repository settings (**Settings > Secrets and variables > Actions**):
1. **`COSIGN_PRIVATE_KEY`**: The complete text content of `cosign.key` (including `-----BEGIN ENCRYPTED SIGSTORE PRIVATE KEY-----` and `-----END ENCRYPTED SIGSTORE PRIVATE KEY-----`).
2. **`COSIGN_PASSWORD`**: The password used to generate the key (if you provided one. If you ran with empty password `COSIGN_PASSWORD=""`, set this secret to an empty value or omit `COSIGN_PASSWORD` in your workflow environment if preferred).

## 3. Manual Signing

To sign an image manually from your terminal:

```bash
# Set environment variables
$env:COSIGN_PASSWORD=""

# Sign the image
docker run --rm -it -e COSIGN_PASSWORD -v "${PWD}/signing:/keys" -w /keys \
  -v "${HOME}/.docker:/root/.docker" \
  ghcr.io/sigstore/cosign/cosign:v2.2.4 sign --key cosign.key <registry>/<image>:<tag>
```

## 4. Manual Verification

To verify a signed image manually using the public key:

```bash
cosign verify --key signing/cosign.pub <registry>/<image>:<tag>
```

Or using Docker:

```bash
docker run --rm -it -v "${PWD}/signing:/keys" -w /keys ghcr.io/sigstore/cosign/cosign:v2.2.4 verify --key cosign.pub <registry>/<image>:<tag>
```

## 5. Troubleshooting Admission Webhook Rejections

If a deployment fails with an admission webhook rejection:

```
Error: admission webhook "policy.sigstore.dev" denied the request: validation failed: image ... does not have a valid signature
```

### Checkpoints:
1. **Verify namespace label**: Check if the namespace is labeled for enforcement:
   ```bash
   kubectl get ns demo --show-labels
   ```
2. **Verify ClusterImagePolicy**: Ensure the policy is active and matching the image glob:
   ```bash
   kubectl get clusterimagepolicies
   ```
3. **Verify registry tag signature**: Check if the image tag is actually signed:
   ```bash
   cosign verify --key signing/cosign.pub <image-reference>
   ```
