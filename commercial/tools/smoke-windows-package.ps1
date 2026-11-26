param([Parameter(Mandatory=$true)][string]$AppDir)
$ErrorActionPreference = 'Stop'
$app = (Resolve-Path -LiteralPath $AppDir).Path
$node = Join-Path $app 'runtime/node.exe'
if (!(Test-Path -LiteralPath (Join-Path $app 'runtime/LICENSE'))) { throw 'Node runtime license missing.' }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('sagi-smoke-' + [Guid]::NewGuid())
function Invoke-PackedHost($duplicate) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $node
    $start.Arguments = '"' + (Join-Path $app 'desktop-host.mjs') + '"'
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.EnvironmentVariables['SAGI_DESKTOP_OPTIONS'] = @{
        dataDir = $fixture
        meta = @{ fixtureId = 'pack-smoke'; home = 'Home'; away = 'Away' }
    } | ConvertTo-Json -Compress
    $start.CreateNoWindow = $true
    $child = [Diagnostics.Process]::Start($start)
    function Read-Reply {
        $read = $child.StandardOutput.ReadLineAsync()
        if (!$read.Wait(8000) -or !$read.Result) { throw 'Packaged host did not respond.' }
        $value = $read.Result | ConvertFrom-Json
        if (!$value.ok) { throw $value.error }
        $value
    }
    try {
        $hostReply = Read-Reply
        $base = ([uri]$hostReply.mobileUrl).GetLeftPart('Authority') + '/api/v1/lan/'
        $child.StandardInput.WriteLine('pair')
        $pair = Read-Reply
        $session = Invoke-RestMethod -Uri ($base+'redeem') -Method Post -ContentType 'application/json' -Body (@{code=$pair.code}|ConvertTo-Json)
        $body = @{fixtureId='pack-smoke';expectedRevision=0;commandId='pack_smoke_goal_01';type='GOAL';side='HOME'}|ConvertTo-Json
        $result = Invoke-RestMethod -Uri ($base+'command') -Method Post -ContentType 'application/json' -Headers @{Authorization="Bearer $($session.token)"} -Body $body
        if ($result.result.duplicate -ne $duplicate -or $result.result.state.homeScore -ne 1) { throw 'Packaged goal or restart check failed.' }
        $child.StandardInput.WriteLine('scoreboard-on')
        [void](Read-Reply)
        $screen = Invoke-RestMethod -Uri ($hostReply.broadcastUrl+'/state')
        if ($screen.homeScore -ne 1 -or !$screen.visible) { throw 'Packaged broadcast output did not reflect the goal.' }
    } finally {
        try {
            $child.StandardInput.Close()
            if (!$child.WaitForExit(8000) -or $child.ExitCode -ne 0) { throw 'Packaged host did not shut down cleanly.' }
        } finally { $child.Dispose() }
    }
}
try {
    Invoke-PackedHost $false
    Invoke-PackedHost $true
    Write-Output 'PASS packaged host, pairing, persisted score, duplicate retry and broadcast state'
} finally {
    if (Test-Path -LiteralPath $fixture) {
        $resolved = (Resolve-Path -LiteralPath $fixture).Path
        if ($resolved -eq $fixture -and (Split-Path -Parent $resolved) -eq [IO.Path]::GetTempPath().TrimEnd('\','/')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
