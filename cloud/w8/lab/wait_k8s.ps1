param (
    [string]$ip,
    [string]$instanceId
)

$keyPath = Join-Path $PSScriptRoot "k8s-key.pem"
$outputPath = Join-Path $PSScriptRoot "kubeconfig_$instanceId.yaml"

# Loop to poll the kind cluster over SSH
for ($i=0; $i -lt 60; $i++) {
    Write-Host "Waiting for Kubernetes to be ready on $ip (attempt $($i+1)/60)..."
    
    # Check if the API server is responsive by running kubectl get nodes
    ssh -i $keyPath -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "sudo kubectl --kubeconfig /tmp/kubeconfig.yaml get nodes" >$null 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        # Fetch the kubeconfig once the API server is ready
        $val = ssh -i $keyPath -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ip "sudo kind get kubeconfig" 2>$null
        
        if ($val -and ($val -like "*apiVersion*")) {
            Write-Host "Before replace: ($($val | Select-String 'server:'))"
            # Replace local endpoints with the instance's public IP
            $val = $val -replace "server: https://127.0.0.1:6443", ("server: https://" + $ip + ":6443")
            $val = $val -replace "server: https://localhost:6443", ("server: https://" + $ip + ":6443")
            $val = $val -replace "server: https://0.0.0.0:6443", ("server: https://" + $ip + ":6443")
            Write-Host "After replace: ($($val | Select-String 'server:'))"
            
            # Save to local file in UTF-8
            $val | Out-File -FilePath $outputPath -Encoding utf8
            Write-Host "Kubeconfig retrieved and saved to $outputPath"
            exit 0
        }
    }
    
    Start-Sleep -Seconds 10
}

Write-Host "Timeout waiting for Kubernetes to be ready"
exit 1
