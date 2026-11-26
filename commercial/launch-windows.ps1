param([string]$NodePath = (Join-Path $PSScriptRoot 'runtime\node.exe'))

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object Windows.Forms.Form
$form.Text = 'SAGI BROADCAST 本地控制'
$form.ClientSize = New-Object Drawing.Size(540, 405)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

function Add-Field($caption, $value, $top) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $caption
    $label.SetBounds(15, $top, 145, 24)
    $form.Controls.Add($label)
    $field = New-Object Windows.Forms.TextBox
    $field.Text = $value
    $field.SetBounds(160, $top, 360, 24)
    $form.Controls.Add($field)
    return $field
}
$home = Add-Field '主队（首次启动）' '' 20
$away = Add-Field '客队（首次启动）' '' 55
$lan = Add-Field '本机局域网 IP' '127.0.0.1' 90
$url = Add-Field '手机访问地址' '' 135
$url.ReadOnly = $true
$code = Add-Field '一次性配对码' '' 170
$code.ReadOnly = $true
$broadcastUrl = Add-Field 'vMix 浏览器输入' '' 204
$broadcastUrl.ReadOnly = $true

$start = New-Object Windows.Forms.Button
$start.Text = '启动本地服务'
$start.SetBounds(160, 248, 160, 32)
$form.Controls.Add($start)
$pair = New-Object Windows.Forms.Button
$pair.Text = '批准手机配对'
$pair.SetBounds(330, 248, 190, 32)
$pair.Enabled = $false
$form.Controls.Add($pair)
$scoreOn = New-Object Windows.Forms.Button
$scoreOn.Text = '显示比分牌'
$scoreOn.SetBounds(160, 290, 160, 30)
$scoreOn.Enabled = $false
$form.Controls.Add($scoreOn)
$scoreOff = New-Object Windows.Forms.Button
$scoreOff.Text = '隐藏比分牌'
$scoreOff.SetBounds(330, 290, 190, 30)
$scoreOff.Enabled = $false
$form.Controls.Add($scoreOff)
$status = New-Object Windows.Forms.Label
$status.SetBounds(15, 335, 510, 60)
$status.Text = '首次启动填写球队。已有比赛会从本机数据目录恢复。'
$form.Controls.Add($status)

function Read-HostReply {
    $pending = $script:sagiHost.StandardOutput.ReadLineAsync()
    if (!$pending.Wait(8000) -or $null -eq $pending.Result) { throw '本地服务未回应' }
    $reply = $pending.Result | ConvertFrom-Json -ErrorAction Stop
    if (!$reply.ok) { throw $reply.error }
    return $reply
}

function Stop-SagiHost {
    if ($null -eq $script:sagiHost) { return }
    try {
        if (!$script:sagiHost.HasExited) {
            $script:sagiHost.StandardInput.Close()
            if (!$script:sagiHost.WaitForExit(8000)) {
                $status.Text = '本地服务仍在关闭，请稍后重试。'
            }
        }
    } finally {
        $script:sagiHost.Dispose()
        $script:sagiHost = $null
    }
}

$start.Add_Click({
    $start.Enabled = $false
    try {
        $node = (Resolve-Path -LiteralPath $NodePath -ErrorAction Stop).Path
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $node
        $info.Arguments = '"' + (Join-Path $PSScriptRoot 'desktop-host.mjs') + '"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardInput = $true
        $info.RedirectStandardOutput = $true
        $info.EnvironmentVariables['SAGI_DESKTOP_OPTIONS'] = (@{
            dataDir = (Join-Path $env:LOCALAPPDATA 'SAGI Broadcast\Match')
            lanHost = $lan.Text.Trim()
            meta = @{ fixtureId = [guid]::NewGuid().ToString(); home = $home.Text; away = $away.Text }
        } | ConvertTo-Json -Compress -Depth 4)
        $script:sagiHost = [Diagnostics.Process]::Start($info)
        $reply = Read-HostReply
        $url.Text = $reply.mobileUrl
        $broadcastUrl.Text = $reply.broadcastUrl
        $pair.Enabled = $true
        $scoreOn.Enabled = $true
        $scoreOff.Enabled = $true
        $status.Text = '服务已启动。手机需连接同一局域网。'
    } catch {
        Stop-SagiHost
        $status.Text = '启动失败：' + $_.Exception.Message
        $start.Enabled = $true
    }
})
$pair.Add_Click({
    $code.Clear()
    try {
        $script:sagiHost.StandardInput.WriteLine('pair')
        $code.Text = (Read-HostReply).code
        $status.Text = '请在手机页面输入配对码。'
    } catch {
        $pair.Enabled = $false
        $scoreOn.Enabled = $false
        $scoreOff.Enabled = $false
        Stop-SagiHost
        $url.Clear()
        $broadcastUrl.Clear()
        $start.Enabled = $true
        $status.Text = '配对失败：' + $_.Exception.Message
    }
})
function Set-ScoreboardOutput($command) {
    try {
        $script:sagiHost.StandardInput.WriteLine($command)
        [void](Read-HostReply)
        $status.Text = if ($command -eq 'scoreboard-on') { '比分牌已显示。' } else { '比分牌已隐藏。' }
    } catch { $status.Text = '比分牌操作失败：' + $_.Exception.Message }
}
$scoreOn.Add_Click({ Set-ScoreboardOutput 'scoreboard-on' })
$scoreOff.Add_Click({ Set-ScoreboardOutput 'scoreboard-off' })
$form.Add_FormClosed({ Stop-SagiHost })
[void]$form.ShowDialog()
