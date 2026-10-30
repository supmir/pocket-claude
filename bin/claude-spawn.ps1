# claude-spawn.ps1: run Claude Code Remote Control servers as background tasks on Windows.
# Same CLI as the bash version. Windows PowerShell 5.1+ or PowerShell 7.
# EXPERIMENTAL: not tested by the author (developed on macOS).
$ErrorActionPreference = 'Stop'

$cfgDir  = Join-Path $env:APPDATA 'pocket-claude'
$cfgFile = Join-Path $cfgDir 'config.json'
$logDir  = Join-Path $env:LOCALAPPDATA 'pocket-claude\logs'
$runDir  = Join-Path $env:LOCALAPPDATA 'pocket-claude\run'
$claudeJson = if ($env:PC_CLAUDE_JSON) { $env:PC_CLAUDE_JSON } else { Join-Path $HOME '.claude.json' }
New-Item -ItemType Directory -Force $cfgDir, $logDir, $runDir | Out-Null

$cfg = @{ root = Join-Path $HOME 'Documents'; hubDir = ''; hubName = "$($env:COMPUTERNAME.ToLower())-hub"; trustUnderRoot = $false }
if (Test-Path $cfgFile) {
  $j = Get-Content $cfgFile -Raw | ConvertFrom-Json
  foreach ($k in @($cfg.Keys)) { if ($null -ne $j.$k) { $cfg[$k] = $j.$k } }
}
if (-not $cfg.hubDir) { $cfg.hubDir = Join-Path $cfg.root 'pocket-claude-hub' }

function Usage {
@'
Usage:
  claude-spawn.ps1 init <projects-root> <hub-dir> <hub-name> <yes|no>   (yes = auto-trust repos under root)
  claude-spawn.ps1 hub
  claude-spawn.ps1 start <owner/repo | git-url | path> [dest]
  claude-spawn.ps1 root | list | url <name> | stop <name>
  claude-spawn.ps1 trust <dir>
'@
}

function LogFile($n)  { Join-Path $logDir "$n.log" }
function TaskName($n) { "pocket-claude-$n" }
function Full($p)     { [IO.Path]::GetFullPath($p).TrimEnd('\') }

function Test-Running($n) {
  $t = Get-ScheduledTask -TaskName (TaskName $n) -ErrorAction SilentlyContinue
  return ($t -and $t.State -eq 'Running')
}

function Stop-Svc($n) {
  Stop-ScheduledTask -TaskName (TaskName $n) -ErrorAction SilentlyContinue
  # the task's child claude process can outlive the wrapper; kill by command line
  Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*remote-control --name $n*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Install-Svc($n, $dir, $persistent) {
  $claude = (Get-Command claude -ErrorAction Stop).Source
  $log = LogFile $n
  $script = Join-Path $runDir "$n.ps1"
  # Wrapper: block system sleep for this thread's lifetime, then run claude in the repo.
  @"
Add-Type -Namespace Pc -Name Pwr -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);'
[void][Pc.Pwr]::SetThreadExecutionState(0x80000001)  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
Set-Location -LiteralPath '$dir'
& '$claude' remote-control --name '$n' *>> '$log'
exit `$LASTEXITCODE
"@ | Set-Content -Encoding UTF8 $script

  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
  # Only the hub has a logon trigger; spawned tasks have none, so they don't survive logout/reboot.
  $trigger = if ($persistent) { @(New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME") } else { @() }
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
  Stop-Svc $n
  Register-ScheduledTask -TaskName (TaskName $n) -Action $action -Settings $settings -Trigger $trigger `
    -Principal $principal -Force | Out-Null
  Start-ScheduledTask -TaskName (TaskName $n)
}

function Get-Url($n) {
  $f = LogFile $n
  if (-not (Test-Path $f)) { return '' }
  $m = Select-String -Path $f -Pattern 'https://claude\.ai/code\?environment=[A-Za-z0-9_]+' -AllMatches
  if (-not $m) { return '' }
  return ($m | ForEach-Object { $_.Matches } | Select-Object -Last 1).Value
}

function Wait-Url($n) {
  1..30 | ForEach-Object { if (Get-Url $n) { return $true }; Start-Sleep 1 }
  return [bool](Get-Url $n)
}

function Get-RepoRoot($d) {
  $r = git -C $d rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $r) { return Full $r }
  return Full $d
}

# Claude may key projects by either slash style; write both.
function Test-Trusted($p) {
  if (-not (Test-Path $claudeJson)) { return $false }
  $j = Get-Content $claudeJson -Raw | ConvertFrom-Json
  foreach ($k in @($p, ($p -replace '\\', '/'))) {
    $e = $j.projects.PSObject.Properties[$k]
    if ($e -and $e.Value.hasTrustDialogAccepted -eq $true) { return $true }
  }
  return $false
}

# Same effect as accepting the trust dialog. Atomic: running Claude processes also rewrite this file.
function Set-Trust($p) {
  $j = if (Test-Path $claudeJson) { Get-Content $claudeJson -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  if (-not $j.PSObject.Properties['projects']) { $j | Add-Member projects ([pscustomobject]@{}) }
  foreach ($k in @($p, ($p -replace '\\', '/'))) {
    $e = $j.projects.PSObject.Properties[$k]
    if (-not $e) { $j.projects | Add-Member $k ([pscustomobject]@{}); $e = $j.projects.PSObject.Properties[$k] }
    if ($e.Value.PSObject.Properties['hasTrustDialogAccepted']) { $e.Value.hasTrustDialogAccepted = $true }
    else { $e.Value | Add-Member hasTrustDialogAccepted $true }
  }
  $tmp = "$claudeJson.$([guid]::NewGuid().ToString('N')).tmp"
  [IO.File]::WriteAllText($tmp, ($j | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding $false))
  Move-Item -Force $tmp $claudeJson
}

function Under-Root($p) { $r = Full $cfg.root; return $p.StartsWith("$r\", [StringComparison]::OrdinalIgnoreCase) }

$cmd = $args[0]
switch ($cmd) {
  'init' {
    if ($args.Count -ne 5) { Usage; exit 1 }
    if ($args[4] -notin 'yes', 'no') { Write-Error 'trust must be yes or no' }
    New-Item -ItemType Directory -Force $args[1] | Out-Null
    @{ root = Full $args[1]; hubDir = Full $args[2]; hubName = $args[3]; trustUnderRoot = ($args[4] -eq 'yes') } |
      ConvertTo-Json | Set-Content -Encoding UTF8 $cfgFile
    "Wrote $cfgFile"
  }
  'hub' {
    $hub = Full $cfg.hubDir
    if (-not (Test-Path "$hub\.git")) {
      New-Item -ItemType Directory -Force $hub | Out-Null
      git -C $hub init -q
      $tpl = Join-Path $PSScriptRoot '..\templates\hub-CLAUDE.md'
      (Get-Content $tpl -Raw).Replace('{{HUB_NAME}}', $cfg.hubName).Replace('{{ROOT}}', $cfg.root) |
        Set-Content -Encoding UTF8 "$hub\CLAUDE.md"
      git -C $hub add CLAUDE.md
      git -C $hub -c user.name=pocket-claude -c user.email=pocket-claude@localhost commit -q -m 'Initial hub CLAUDE.md'
    }
    Set-Trust (Get-RepoRoot $hub)
    Set-Content (LogFile $cfg.hubName) ''
    Install-Svc $cfg.hubName (Get-RepoRoot $hub) $true
    if (Wait-Url $cfg.hubName) { "$($cfg.hubName): $(Get-Url $cfg.hubName)" }
    else { [Console]::Error.WriteLine("No session URL yet; check: $(LogFile $cfg.hubName)"); exit 1 }
  }
  'start' {
    $src = $args[1]
    if (-not $src) { Usage; exit 1 }
    if (Test-Path -LiteralPath $src -PathType Container) { $dir = (Resolve-Path -LiteralPath $src).Path }
    else {
      $dest = if ($args[2]) { $args[2] } else { [IO.Path]::GetFileNameWithoutExtension($src.TrimEnd('/')) }
      $dir = Join-Path $cfg.root $dest
      if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force (Split-Path $dir) | Out-Null
        if ($src -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { gh repo clone $src $dir } else { git clone $src $dir }
      }
    }
    $root = Get-RepoRoot $dir
    $rel = if (Under-Root $root) { $root.Substring((Full $cfg.root).Length + 1) } else { Split-Path $root -Leaf }
    $name = $rel -replace '[\\/]', '-' -replace '[^A-Za-z0-9_.-]', '-'

    if (-not (Test-Trusted $root)) {
      if (Under-Root $root) {
        if (-not $cfg.trustUnderRoot) {
          [Console]::Error.WriteLine("Not trusted yet: $root")
          [Console]::Error.WriteLine("Auto-trust is off. Review the repo, then run: claude-spawn.ps1 trust '$root'")
          [Console]::Error.WriteLine('(or run claude there once from a terminal and accept the dialog)')
          exit 2
        }
        "Trusting $root"
        foreach ($f in '.claude', '.mcp.json', 'CLAUDE.md') {
          if (Test-Path (Join-Path $root $f)) { "  note: repo ships $f; its settings, hooks and MCP servers will apply" }
        }
        Set-Trust $root
      } else {
        [Console]::Error.WriteLine("Not trusted yet: $root (only $($cfg.root)\* can be auto-trusted)")
        [Console]::Error.WriteLine("Trust it once from a terminal: cd '$root'; claude  (accept, then /exit)")
        exit 2
      }
    }

    if (Test-Running $name) { "Already running: $name" }
    else {
      Set-Content (LogFile $name) ''
      Install-Svc $name $root $false
      if (-not (Wait-Url $name) -and (Select-String -Path (LogFile $name) -Pattern 'Workspace not trusted' -Quiet)) {
        Set-Trust $root   # another claude process clobbered the entry; re-trust once
        Install-Svc $name $root $false
        [void](Wait-Url $name)
      }
    }
    $url = Get-Url $name
    if ($url) { "${name}: $url" }
    elseif (Select-String -Path (LogFile $name) -Pattern 'already served' -Quiet) {
      Stop-Svc $name
      [Console]::Error.WriteLine("$root already has a Remote Control server (e.g. the hub); use that one.")
      exit 3
    } else { [Console]::Error.WriteLine("No session URL yet; check: $(LogFile $name)"); exit 1 }
  }
  'trust' { Set-Trust (Get-RepoRoot (Resolve-Path $args[1]).Path); 'Trusted.' }
  'root'  { $cfg.root }
  'list'  {
    $t = Get-ScheduledTask -TaskName 'pocket-claude-*' -ErrorAction SilentlyContinue
    if ($t) { $t | Select-Object TaskName, State | Format-Table -AutoSize } else { 'none running' }
  }
  'url'   { Get-Url $args[1] }
  'stop'  { Stop-Svc $args[1]; Unregister-ScheduledTask -TaskName (TaskName $args[1]) -Confirm:$false -ErrorAction SilentlyContinue }
  default { Usage; exit 1 }
}
