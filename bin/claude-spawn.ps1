# claude-spawn.ps1: run Claude Code Remote Control servers as background tasks on Windows.
# Same commands as the bash version, minus automatic folder approval (Windows: approve by hand).
# EXPERIMENTAL: not tested by the maintainer. Windows PowerShell 5.1+ or PowerShell 7.
$ErrorActionPreference = 'Stop'

function Die($msg, $code = 1) { [Console]::Error.WriteLine($msg); exit $code }

$here    = $PSScriptRoot
$cfgDir  = Join-Path $env:APPDATA 'pocket-claude'
$cfgFile = Join-Path $cfgDir 'config.json'
$share   = Join-Path $env:LOCALAPPDATA 'pocket-claude'
$logDir  = Join-Path $share 'logs'
$runDir  = Join-Path $share 'run'
$stateDir = Join-Path $share 'state'
New-Item -ItemType Directory -Force $cfgDir, $logDir, $runDir, $stateDir | Out-Null

$cfg = @{ root = (Join-Path $HOME 'projects'); hubName = ($env:COMPUTERNAME.ToLower() -replace '[^A-Za-z0-9._-]', '-') + '-hub'; permissionMode = 'default' }
if (Test-Path $cfgFile) {
  $j = Get-Content $cfgFile -Raw | ConvertFrom-Json
  foreach ($k in @($cfg.Keys)) { if ($null -ne $j.$k) { $cfg[$k] = [string]$j.$k } }
}
$hubDir = Join-Path $HOME 'pocket-claude-hub'

function Test-Name($n)  { return $n -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' }
function Test-Path-Safe($p) { return $p -notmatch '["''<>&%$`;]' }   # these end up inside generated scripts
function Test-Dest($d)  { return ($d -and $d -notmatch '^[\\/]' -and $d -notmatch '^-' -and $d -notmatch '(^|[\\/])\.\.($|[\\/])' -and $d -notmatch '^[A-Za-z]:' -and (Test-Path-Safe $d)) }
if (-not (Test-Name $cfg.hubName)) { Die "Config problem: hub name '$($cfg.hubName)' is not allowed." }
if ($cfg.permissionMode -notin 'default', 'acceptEdits', 'plan') { Die 'Config problem: permission mode is not allowed.' }
if (-not (Test-Path-Safe $cfg.root)) { Die 'Config problem: projects folder path contains an unsupported character.' }

function Save-Config { $cfg | ConvertTo-Json | Set-Content -Encoding UTF8 $cfgFile }
function LogFile($n)  { Join-Path $logDir "$n.log" }
function TaskName($n) { "pocket-claude-$n" }
function Full($p)     { [IO.Path]::GetFullPath($p).TrimEnd('\') }
function Spawn-Cmd    { "powershell -NoProfile -ExecutionPolicy Bypass -File `"$share\bin\claude-spawn.ps1`"" }

function Usage {
@'
Usage:  (run as: powershell -NoProfile -ExecutionPolicy Bypass -File claude-spawn.ps1 <command>)
  install | hub | doctor
  set root <folder> | hub-name <name> | permission-mode default|acceptEdits|plan
  start <owner/repo | git-url | folder> [dest]
  list | url <name> | stop <name|all>
  uninstall [--hub-folder] [--config] [--logs]
'@
}

function Test-Running($n) {
  $t = Get-ScheduledTask -TaskName (TaskName $n) -ErrorAction SilentlyContinue
  return [bool]($t -and $t.State -eq 'Running')
}

function Stop-Svc($n) {
  Stop-ScheduledTask -TaskName (TaskName $n) -ErrorAction SilentlyContinue
  $pat = 'remote-control --name ' + [regex]::Escape($n) + '(\s|$)'
  Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $pat } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Remove-Svc($n) {
  Stop-Svc $n
  Unregister-ScheduledTask -TaskName (TaskName $n) -Confirm:$false -ErrorAction SilentlyContinue
}

function Install-Svc($n, $dir, $persistent) {
  $claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
  if (-not $claude) { Die "Claude Code ('claude') wasn't found on this computer's PATH." }
  if (-not (Test-Path-Safe $claude)) { Die "The path to claude contains an unsupported character: $claude" }
  if (-not (Test-Path-Safe $dir)) { Die "UNSUPPORTED_PATH: '$dir' contains a character this tool can't handle safely (quotes, & < > % `$ backtick ;)." }
  $log = LogFile $n
  $modeArgs = if ($cfg.permissionMode -ne 'default') { "--permission-mode $($cfg.permissionMode)" } else { '' }
  $script = Join-Path $runDir "$n.ps1"
  # Wrapper: block system sleep for this thread's lifetime, empty the log, run claude in the repo.
  $body = @'
Add-Type -Namespace Pc -Name Pwr -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);'
[void][Pc.Pwr]::SetThreadExecutionState(0x80000001)  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
Set-Location -LiteralPath "@DIR@"
Set-Content -LiteralPath "@LOG@" -Value '' -Encoding UTF8
& "@CLAUDE@" remote-control --name "@NAME@" @MODE@ 2>&1 | ForEach-Object { Add-Content -LiteralPath "@LOG@" -Value ([string]$_) -Encoding UTF8 }
exit $LASTEXITCODE
'@
  $body = $body.Replace('@DIR@', $dir).Replace('@LOG@', $log).Replace('@CLAUDE@', $claude).Replace('@NAME@', $n).Replace('@MODE@', $modeArgs)
  Set-Content -Encoding UTF8 -LiteralPath $script -Value $body

  $user = "$env:USERDOMAIN\$env:USERNAME"
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
  $reg = @{ TaskName = (TaskName $n); Action = $action; Settings = $settings; Force = $true
            Principal = (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive) }
  # Only the hub starts at login; spawned tasks have no trigger, so they don't survive logout/reboot.
  if ($persistent) { $reg.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $user }
  Stop-Svc $n
  Register-ScheduledTask @reg | Out-Null
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
  for ($i = 0; $i -lt 30; $i++) { if (Get-Url $n) { return $true }; Start-Sleep 1 }
  return $false
}

function Log-Tail($n) { if (Test-Path (LogFile $n)) { (Get-Content (LogFile $n) -Tail 5) -replace '\x1b\[[0-9;?]*[A-Za-z]', '' } }

function Get-RepoRoot($d) {
  $r = git -C $d rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $r) { return Full $r }
  return Full $d
}

function Under-Root($p) { return $p.StartsWith((Full $cfg.root) + '\', [StringComparison]::OrdinalIgnoreCase) }

function Derive-Name($root) {
  $rel = if (Under-Root $root) { $root.Substring((Full $cfg.root).Length + 1) } else { Split-Path $root -Leaf }
  $name = ($rel -replace '[^A-Za-z0-9_.-]', '-') -replace '^[-.]+', ''
  if (-not $name) { $name = 'repo' }
  if ($name.Length -gt 48) { $name = $name.Substring(0, 48) }
  $sf = Join-Path $stateDir "$name.dir"
  if ((Test-Path $sf) -and ((Get-Content $sf -Raw).Trim() -ne $root)) {
    $h = [BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($root))).Replace('-', '').Substring(0, 6).ToLower()
    $name = "$name-$h"
  }
  return $name
}

$notTrusted = {
  param($root, $why)
  [Console]::Error.WriteLine("NOT_TRUSTED: $root hasn't been approved to run Claude sessions yet. $why")
  [Console]::Error.WriteLine("On Windows, approve it by hand once: open a terminal, run  cd '$root'; claude  and choose Yes at the trust prompt, then type /exit. Ask the user first: approving lets that folder's own settings and tools run commands here.")
}

$cmd = $args[0]
switch ($cmd) {
  'install' {
    $src = Split-Path $here -Parent
    if ((Full $src) -eq (Full $share)) { 'Already installed'; break }
    New-Item -ItemType Directory -Force (Join-Path $share 'bin'), (Join-Path $share 'templates') | Out-Null
    Copy-Item -Force (Join-Path $src 'bin\*') (Join-Path $share 'bin')
    Copy-Item -Force (Join-Path $src 'templates\*') (Join-Path $share 'templates')
    if (Test-Path (Join-Path $src 'VERSION')) { Copy-Item -Force (Join-Path $src 'VERSION') $share }
    "Installed to $share"
  }
  'set' {
    $key = $args[1]; $val = $args[2]
    if (-not $key -or -not $val) { Usage; exit 1 }
    switch ($key) {
      'root' {
        New-Item -ItemType Directory -Force $val | Out-Null
        $val = Full $val
        if (-not (Test-Path-Safe $val)) { Die "That folder's path contains an unsupported character." }
        $cfg.root = $val
      }
      'hub-name' { if (-not (Test-Name $val)) { Die 'Name must be letters, digits, . _ - only (max 64).' }; $cfg.hubName = $val }
      'permission-mode' { if ($val -notin 'default', 'acceptEdits', 'plan') { Die 'Mode must be one of: default, acceptEdits, plan.' }; $cfg.permissionMode = $val }
      default { Die "Unknown setting: $key" }
    }
    Save-Config; 'Saved.'
  }
  'hub' {
    if (-not (Test-Path (Join-Path $share 'bin\claude-spawn.ps1'))) { & $PSCommandPath install | Out-Null }
    if (-not (Test-Path-Safe $hubDir)) { Die "UNSUPPORTED_PATH: hub folder path '$hubDir' contains an unsupported character." }
    New-Item -ItemType Directory -Force $hubDir | Out-Null
    if (-not (Test-Path (Join-Path $hubDir '.git'))) { git -C $hubDir init -q }
    $t = (Get-Content (Join-Path $share 'templates\hub-CLAUDE.md') -Raw).Replace('{{HUB_NAME}}', $cfg.hubName).Replace('{{ROOT}}', $cfg.root).Replace('{{SPAWN}}', (Spawn-Cmd))
    Set-Content -Encoding UTF8 (Join-Path $hubDir 'CLAUDE.md') $t
    git -C $hubDir add -A
    git -C $hubDir diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { git -C $hubDir -c commit.gpgsign=false -c user.name=pocket-claude -c user.email=pocket-claude@localhost commit -q -m 'Update hub files' }
    Install-Svc $cfg.hubName (Full $hubDir) $true
    Set-Content (Join-Path $stateDir "$($cfg.hubName).dir") (Full $hubDir)
    if (Wait-Url $cfg.hubName) { "$($cfg.hubName): $(Get-Url $cfg.hubName)" }
    elseif (Select-String -Path (LogFile $cfg.hubName) -Pattern 'Workspace not trusted' -Quiet) {
      Stop-Svc $cfg.hubName; & $notTrusted (Full $hubDir) ''; exit 2
    } else { Die ("NO_URL: the hub didn't start. Last lines of its log:`n" + ((Log-Tail $cfg.hubName) -join "`n")) }
  }
  'start' {
    $src = $args[1]
    if (-not $src) { Usage; exit 1 }
    if (Test-Path -LiteralPath $src -PathType Container) { $dir = (Resolve-Path -LiteralPath $src).Path }
    else {
      $dest = if ($args[2]) { $args[2] } else { [IO.Path]::GetFileNameWithoutExtension($src.TrimEnd('/')) }
      if (-not (Test-Dest $dest)) { Die "BAD_DESTINATION: '$dest' isn't a valid folder name." }
      $dir = Join-Path $cfg.root $dest
      if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force (Split-Path $dir) | Out-Null
        $env:GIT_TERMINAL_PROMPT = '0'
        if ($src -match '^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$') {
          if ((Get-Command gh -ErrorAction SilentlyContinue) -and (gh auth status 2>$null; $LASTEXITCODE -eq 0)) { gh repo clone $src $dir }
          else { git clone -- "https://github.com/$src.git" $dir }
        } elseif ($src -match '^(https://|ssh://|git@)\S+$') { git clone -- $src $dir }
        else { Die "BAD_SOURCE: '$src' isn't a folder, an owner/repo, or a git URL." }
        if ($LASTEXITCODE -ne 0) { Die "CLONE_FAILED: couldn't download $src. If it's private, sign in to GitHub first (gh auth login)." }
      }
    }
    $root = Get-RepoRoot $dir
    $name = Derive-Name $root
    if (Test-Running $name) { "Already running: $name" }
    else {
      Set-Content (Join-Path $stateDir "$name.dir") $root
      Install-Svc $name $root $false
      [void](Wait-Url $name)
    }
    $url = Get-Url $name
    if ($url) { "${name}: $url" }
    elseif (Select-String -Path (LogFile $name) -Pattern 'Workspace not trusted' -Quiet) {
      Remove-Svc $name; & $notTrusted $root ''; exit 2
    }
    elseif (Select-String -Path (LogFile $name) -Pattern 'already served' -Quiet) {
      Remove-Svc $name; Remove-Item (Join-Path $stateDir "$name.dir") -ErrorAction SilentlyContinue
      Die "ALREADY_SERVED: $root already has a session server (for example the hub). Use that one." 3
    } else { Stop-Svc $name; Die ("NO_URL: the session didn't start. Last lines of its log:`n" + ((Log-Tail $name) -join "`n")) }
  }
  'root' { $cfg.root }
  'list' {
    $any = $false
    Get-ChildItem $stateDir -Filter *.dir -ErrorAction SilentlyContinue | ForEach-Object {
      $any = $true; $n = $_.BaseName
      $kind = if ($n -eq $cfg.hubName) { 'hub' } else { 'session' }
      if (Test-Running $n) { "$n  [$kind, running]  $((Get-Content $_.FullName -Raw).Trim())  $(Get-Url $n)" }
      else { "$n  [$kind, stopped]  $((Get-Content $_.FullName -Raw).Trim())" }
    }
    if (-not $any) { 'none' }
  }
  'url' { if (-not (Test-Name $args[1])) { Die 'Bad name.' }; Get-Url $args[1] }
  'stop' {
    $n = $args[1]
    if ($n -eq 'all') {
      Get-ChildItem $stateDir -Filter *.dir -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -ne $cfg.hubName } | ForEach-Object { Stop-Svc $_.BaseName }
      'Stopped all sessions (the hub keeps running).'
    } else {
      if (-not (Test-Name $n)) { Die 'Bad name.' }
      Stop-Svc $n
    }
  }
  'doctor' {
    if (Get-Command claude -ErrorAction SilentlyContinue) { "ok:   claude $(claude --version 2>$null)" } else { 'WARN: claude not found' }
    if (Get-Command git -ErrorAction SilentlyContinue) { 'ok:   git' } else { 'WARN: git not found' }
    if (Test-Running $cfg.hubName) { "ok:   hub '$($cfg.hubName)' running: $(Get-Url $cfg.hubName)" } else { "WARN: hub '$($cfg.hubName)' is not running" }
    'note: closing the lid or sleeping on battery will pause sessions on Windows laptops.'
  }
  'uninstall' {
    $rest = $args[1..($args.Count)]
    foreach ($a in $rest) { if ($a -and $a -notin '--hub-folder', '--config', '--logs') { Die "Unknown option: $a" } }
    Get-ChildItem $stateDir -Filter *.dir -ErrorAction SilentlyContinue | ForEach-Object { Remove-Svc $_.BaseName }
    Remove-Svc $cfg.hubName
    if ($rest -contains '--hub-folder') { Remove-Item -Recurse -Force $hubDir -ErrorAction SilentlyContinue }
    if ($rest -contains '--config') { Remove-Item -Recurse -Force $cfgDir -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force $stateDir, $runDir -ErrorAction SilentlyContinue
    if ($rest -contains '--logs') { Remove-Item -Recurse -Force $logDir -ErrorAction SilentlyContinue }
    'Removed all pocket-claude tasks.'
    Remove-Item -Recurse -Force (Join-Path $share 'bin'), (Join-Path $share 'templates') -ErrorAction SilentlyContinue
  }
  default { Usage; exit 1 }
}
