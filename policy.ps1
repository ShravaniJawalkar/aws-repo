$policyContent = Get-Content -Path "C:\Users\Shravani_Jawalkar\aws\replication-policy.json" -Raw
$escapedPolicy = $policyContent -replace '"', '\"'
$cliInput = @"
{
  "RoleName": "S3ReplicationRole",
  "PolicyName": "S3ReplicationPolicy",
  "PolicyDocument": "$escapedPolicy"
}
"@
$cliInput | Out-File -FilePath "cli-input.json" -Encoding utf8
aws iam put-role-policy --cli-input-json file://cli-input.json --profile user-iam-profile