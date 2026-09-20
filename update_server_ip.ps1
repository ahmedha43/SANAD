param (
    [string]$ServerIp,
    [int]$BackendPort
)

$scriptPath = Join-Path $PSScriptRoot "update_server_ip.py"
if (-not (Test-Path $scriptPath)) {
    Write-Error "Script update_server_ip.py not found at $scriptPath"
    exit 1
}

$pyCmd = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pyCmd = "py"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pyCmd = "python"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pyCmd = "python3"
} else {
    Write-Error "Python runtime (py or python) not found in system."
    exit 1
}

$argsList = @($scriptPath)
if ($ServerIp) {
    $argsList += $ServerIp
}
if ($BackendPort) {
    $argsList += $BackendPort
}

& $pyCmd @argsList
