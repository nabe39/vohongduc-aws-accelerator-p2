<?php
require_once 'config.php';

// Test Database Connection
$db_status = "connecting";
$db_error = "";
$db_logs = [];

$conn = @mysqli_connect(DB_HOST, DB_USER, DB_PASS);
if (!$conn) {
    $db_status = "failed";
    $db_error = mysqli_connect_error();
} else {
    // Select or Create Database
    if (!@mysqli_select_db($conn, DB_NAME)) {
        // Database might not exist yet, try creating it
        if (@mysqli_query($conn, "CREATE DATABASE " . DB_NAME)) {
            @mysqli_select_db($conn, DB_NAME);
        } else {
            $db_status = "failed";
            $db_error = "Could not select or create database: " . mysqli_error($conn);
        }
    }
    
    if ($db_status !== "failed") {
        $db_status = "success";
        
        // Create table for logging visits
        $table_query = "CREATE TABLE IF NOT EXISTS visit_log (
            id INT AUTO_INCREMENT PRIMARY KEY,
            visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            client_ip VARCHAR(45) NOT NULL
        )";
        @mysqli_query($conn, $table_query);
        
        // Log current visit
        $client_ip = $_SERVER['REMOTE_ADDR'];
        $insert_query = "INSERT INTO visit_log (client_ip) VALUES ('$client_ip')";
        @mysqli_query($conn, $insert_query);
        
        // Retrieve last 5 visits
        $result = @mysqli_query($conn, "SELECT id, visited_at, client_ip FROM visit_log ORDER BY id DESC LIMIT 5");
        if ($result) {
            while ($row = mysqli_fetch_assoc($result)) {
                $db_logs[] = $row;
            }
        }
    }
    @mysqli_close($conn);
}

// Test S3 Bucket Connectivity (write and read file using IAM profile & AWS CLI)
$s3_status = "connecting";
$s3_error = "";
$s3_files = [];
$test_file_name = "test_connection_" . time() . ".txt";
$test_file_path = "/tmp/" . $test_file_name;

// Create local test file
file_put_contents($test_file_path, "Test connectivity from " . INSTANCE_ID . " at " . date('Y-m-d H:i:s'));

// Copy to S3
$upload_cmd = "aws s3 cp " . escapeshellarg($test_file_path) . " s3://" . S3_BUCKET . "/" . $test_file_name . " --region " . AWS_REGION . " 2>&1";
exec($upload_cmd, $upload_output, $upload_status);

if ($upload_status !== 0) {
    $s3_status = "failed";
    $s3_error = "Upload failed: " . implode("<br>", $upload_output);
} else {
    // List S3 Objects
    $list_cmd = "aws s3 ls s3://" . S3_BUCKET . " --region " . AWS_REGION . " 2>&1";
    exec($list_cmd, $list_output, $list_status);
    if ($list_status !== 0) {
        $s3_status = "failed";
        $s3_error = "List bucket failed: " . implode("<br>", $list_output);
    } else {
        $s3_status = "success";
        foreach ($list_output as $line) {
            $s3_files[] = htmlspecialchars($line);
        }
    }
    
    // Cleanup S3 test file older than 5 minutes to keep it tidy
    // (Optional but good practice)
}
@unlink($test_file_path);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Cloud Web Application Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&family=Space+Grotesk:wght@400;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0b0f19;
            --card-bg: rgba(22, 28, 45, 0.7);
            --border-color: rgba(255, 255, 255, 0.08);
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --primary-gradient: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
            --accent-success: #10b981;
            --accent-error: #ef4444;
            --accent-warning: #f59e0b;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Outfit', sans-serif;
            background-color: var(--bg-color);
            background-image: 
                radial-gradient(at 10% 20%, rgba(29, 78, 216, 0.15) 0px, transparent 50%),
                radial-gradient(at 90% 80%, rgba(16, 185, 129, 0.1) 0px, transparent 50%);
            color: var(--text-primary);
            min-height: 100vh;
            padding: 2rem;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        header {
            width: 100%;
            max-width: 1200px;
            text-align: center;
            margin-bottom: 3rem;
            padding: 2rem;
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            backdrop-filter: blur(12px);
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
        }

        h1 {
            font-family: 'Space Grotesk', sans-serif;
            font-size: 2.5rem;
            font-weight: 700;
            background: linear-gradient(90deg, #3b82f6, #60a5fa, #10b981);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 0.5rem;
        }

        header p {
            color: var(--text-secondary);
            font-size: 1.1rem;
        }

        .container {
            width: 100%;
            max-width: 1200px;
            display: grid;
            grid-template-columns: 1fr;
            gap: 2rem;
        }

        @media (min-width: 768px) {
            .container {
                grid-template-columns: 1fr 1fr;
            }
            .full-width {
                grid-column: span 2;
            }
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            padding: 2rem;
            backdrop-filter: blur(12px);
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            transition: transform 0.3s ease, border-color 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
            border-color: rgba(59, 130, 246, 0.3);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.5rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            padding-bottom: 1rem;
        }

        .card-title {
            font-family: 'Space Grotesk', sans-serif;
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff;
        }

        .badge {
            padding: 0.35rem 0.8rem;
            border-radius: 100px;
            font-size: 0.85rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .badge-success {
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-success);
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .badge-error {
            background: rgba(239, 68, 68, 0.15);
            color: var(--accent-error);
            border: 1px solid rgba(239, 68, 68, 0.3);
        }

        .meta-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 1.5rem;
        }

        .meta-item {
            display: flex;
            flex-direction: column;
            gap: 0.25rem;
        }

        .meta-label {
            font-size: 0.85rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .meta-value {
            font-size: 1.1rem;
            font-weight: 600;
            color: #fff;
        }

        .error-message {
            background: rgba(239, 68, 68, 0.08);
            border: 1px solid rgba(239, 68, 68, 0.2);
            border-radius: 8px;
            padding: 1rem;
            color: #fca5a5;
            font-family: monospace;
            font-size: 0.9rem;
            margin-top: 1rem;
            word-break: break-all;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 1rem;
            text-align: left;
        }

        th {
            font-size: 0.85rem;
            text-transform: uppercase;
            color: var(--text-secondary);
            padding: 0.75rem 1rem;
            border-bottom: 1px solid var(--border-color);
        }

        td {
            padding: 0.75rem 1rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.03);
            color: #e2e8f0;
            font-size: 0.95rem;
        }

        tr:last-child td {
            border-bottom: none;
        }

        .file-list {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            max-height: 200px;
            overflow-y: auto;
            padding: 0.5rem;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 8px;
            font-family: monospace;
            font-size: 0.9rem;
            border: 1px solid var(--border-color);
        }

        .file-list li {
            padding: 0.25rem 0.5rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.02);
            color: #a7f3d0;
        }

        footer {
            margin-top: 4rem;
            color: var(--text-secondary);
            font-size: 0.9rem;
            text-align: center;
        }
    </style>
</head>
<body>

    <header>
        <h1>AWS Web Application Dashboard</h1>
        <p>Premium Cloud Deployment Infrastructure Demo &bull; Orchestrated via Terraform</p>
    </header>

    <div class="container">
        
        <!-- EC2 Info Card -->
        <div class="card">
            <div class="card-header">
                <span class="card-title">EC2 Web Server</span>
                <span class="badge badge-success">Online</span>
            </div>
            <div class="meta-grid">
                <div class="meta-item">
                    <span class="meta-label">Instance ID</span>
                    <span class="meta-value"><?php echo INSTANCE_ID; ?></span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Availability Zone</span>
                    <span class="meta-value"><?php echo AZ; ?></span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Public IP</span>
                    <span class="meta-value"><?php echo PUBLIC_IP; ?></span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Web Server</span>
                    <span class="meta-value">Apache2 + PHP</span>
                </div>
            </div>
        </div>

        <!-- S3 Bucket Info Card -->
        <div class="card">
            <div class="card-header">
                <span class="card-title">S3 Bucket Storage</span>
                <?php if ($s3_status === "success"): ?>
                    <span class="badge badge-success">Connected</span>
                <?php else: ?>
                    <span class="badge badge-error">Failed</span>
                <?php endif; ?>
            </div>
            <div class="meta-grid" style="margin-bottom: 1.5rem;">
                <div class="meta-item" style="grid-column: span 2;">
                    <span class="meta-label">S3 Bucket Name</span>
                    <span class="meta-value"><?php echo S3_BUCKET; ?></span>
                </div>
            </div>
            <?php if ($s3_status === "success"): ?>
                <span class="meta-label">Recent Objects in Bucket:</span>
                <ul class="file-list">
                    <?php if (empty($s3_files)): ?>
                        <li style="color: var(--text-secondary);">Bucket is currently empty.</li>
                    <?php else: ?>
                        <?php foreach ($s3_files as $file): ?>
                            <li><?php echo $file; ?></li>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </ul>
            <?php else: ?>
                <div class="error-message">
                    <?php echo $s3_error; ?>
                </div>
            <?php endif; ?>
        </div>

        <!-- RDS DB Info Card -->
        <div class="card full-width">
            <div class="card-header">
                <span class="card-title">RDS MySQL Database</span>
                <?php if ($db_status === "success"): ?>
                    <span class="badge badge-success">Connected</span>
                <?php else: ?>
                    <span class="badge badge-error">Connection Failed</span>
                <?php endif; ?>
            </div>
            <div class="meta-grid" style="margin-bottom: 1.5rem;">
                <div class="meta-item">
                    <span class="meta-label">DB Host Endpoint</span>
                    <span class="meta-value"><?php echo DB_HOST; ?></span>
                </div>
                <div class="meta-item">
                    <span class="meta-label">Database Name</span>
                    <span class="meta-value"><?php echo DB_NAME; ?></span>
                </div>
            </div>
            
            <?php if ($db_status === "success"): ?>
                <span class="meta-label">Recent Visitor Logs (Written and Read from DB):</span>
                <table>
                    <thead>
                        <tr>
                            <th>Log ID</th>
                            <th>Timestamp</th>
                            <th>Visitor Client IP</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($db_logs as $log): ?>
                            <tr>
                                <td>#<?php echo $log['id']; ?></td>
                                <td><?php echo $log['visited_at']; ?></td>
                                <td><?php echo $log['client_ip']; ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php else: ?>
                <div class="error-message">
                    <?php echo $db_error; ?>
                </div>
            <?php endif; ?>
        </div>

    </div>

    <footer>
        <p>&copy; <?php echo date('Y'); ?> &bull; Antigravity Deployment Agent</p>
    </footer>

</body>
</html>
