param(
    [Parameter(Mandatory=$true)][string]$NodeArchive,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$NodeSha256,
    [Parameter(Mandatory=$true)][string]$OutputZip
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$archive = (Resolve-Path -LiteralPath $NodeArchive).Path
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputZip)
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $NodeSha256) {
    throw 'Node archive SHA-256 did not match the expected digest.'
}
if (Test-Path -LiteralPath $output) {
    throw 'Output ZIP already exists. Choose a new filename.'
}
$stage = Join-Path ([IO.Path]::GetTempPath()) ('sagi-package-' + [Guid]::NewGuid())
$source = Join-Path $stage 'node'
$app = Join-Path $stage 'SAGI Broadcast'
try {
    New-Item -ItemType Directory -Path $source,$app | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $source
    $node = @(Get-ChildItem -LiteralPath $source -Directory | Where-Object Name -Match '^node-v(?:22|24)\.\d+\.\d+-win-x64$')
    if ($node.Count -ne 1) { throw 'Expected one official Node.js 22 or 24 Windows x64 archive directory.' }
    $runtime = New-Item -ItemType Directory -Path (Join-Path $app 'runtime')
    foreach ($name in @('node.exe','LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $node[0].FullName $name) -Destination $runtime.FullName
    }
    $reported = & (Join-Path $runtime.FullName 'node.exe') -p "process.version + '/' + process.platform + '/' + process.arch"
    if ($LASTEXITCODE -ne 0 -or $reported -ne ($node[0].Name.Replace('node-','').Replace('-win-x64','')+'/win32/x64')) {
        throw 'Runtime version or platform does not match the archive directory.'
    }
    foreach ($name in @('desktop-host.mjs','runtime.mjs','launch-windows.ps1','WINDOWS-PREVIEW.txt')) {
        Copy-Item -LiteralPath (Join-Path $repo "commercial/$name") -Destination $app
    }
    foreach ($layer in @('core','director','lan')) {
        $dest = New-Item -ItemType Directory -Path (Join-Path $app $layer)
        Get-ChildItem -LiteralPath (Join-Path $repo "commercial/$layer") -Filter '*.mjs' -File |
            Where-Object Name -NotLike '*selftest.mjs' |
            Copy-Item -Destination $dest.FullName
    }
    @'
@echo off
start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "%~dp0launch-windows.ps1"
'@ | Set-Content -LiteralPath (Join-Path $app 'Start SAGI Broadcast.cmd') -Encoding ASCII
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
    Compress-Archive -LiteralPath $app -DestinationPath $output
    $digest = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($output+'.sha256'), ('{0}  {1}{2}' -f $digest,[IO.Path]::GetFileName($output),[Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Write-Output $output
} finally {
    if (Test-Path -LiteralPath $stage) {
        $resolved = (Resolve-Path -LiteralPath $stage).Path
        if ($resolved -eq $stage -and (Split-Path -Parent $resolved) -eq [IO.Path]::GetTempPath().TrimEnd('\','/')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
