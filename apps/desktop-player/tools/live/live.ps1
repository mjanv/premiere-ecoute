# Live checks of how the player drives the real Spotify desktop app, run through the media session.
# Not unit tests: they need Spotify running and signed in on this PC, and they take over what plays.
#
#   live.ps1 -Exe <player built with --features dev-tools> -Scenario end|first-track|other-album|shuffle|restart|all
#
# The player is started like a streamer's, but never joins a server (PLAYER_HUB_URL points nowhere)
# and does not take the single-instance lock (PLAYER_UI_PREVIEW): it can run next to a real player.
# Tracks are real Spotify tracks (the albums of docs/guides' fixtures), played from Spotify's catalogue.
param(
    [Parameter(Mandatory)][string]$Exe,
    [string]$Scenario = 'all',
    [string]$Log = (Join-Path $env:LOCALAPPDATA 'premiere-ecoute-player\player.log')
)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaPlaybackAutoRepeatMode, Windows.Media, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); if (-not $t.Wait(5000)) { return $null }; $t.Result }
$manager = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$properties = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]
$mgr = Await ($manager::RequestAsync()) $manager

# Billie Eilish, "WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?": track id, number, exact length in ms.
$Album = @{
    t1 = @('0rQtoQXQfwpDW0c7Fw1NeM', 1, 13578);   t2 = @('2Fxmhks0bxGSBdJ92vM42m', 2, 194087)
    t3 = @('4QIo4oxwzzafcBWkKjDpXY', 3, 243725);  t4 = @('3XF5xLJHOQQRbWya6hBp7d', 4, 180952)
}
# Pink Floyd, "The Dark Side of the Moon": a second album, so "another album" is really another.
$OtherAlbumTrack = '6rqhFgbbKwnb9MLmUQDhG6'

# Not `Sp`: that is a built-in alias (Set-ItemProperty), and an alias wins over a function.
function Get-Spotify { $mgr.GetSessions() | Where-Object { $_.SourceAppUserModelId -match 'spotify' } | Select-Object -First 1 }
function State {
    $s = Get-Spotify; $p = Await ($s.TryGetMediaPropertiesAsync()) $properties; $tl = $s.GetTimelineProperties(); $i = $s.GetPlaybackInfo()
    [pscustomobject]@{
        Status = "$($i.PlaybackStatus)"; Title = $p.Title; Number = $p.TrackNumber
        Pos = $tl.Position.TotalSeconds; End = $tl.EndTime.TotalSeconds
        Shuffle = ($i.IsShuffleActive | Out-String).Trim(); Repeat = ($i.AutoRepeatMode | Out-String).Trim()
    }
}
function Pause-Spotify { $s = Get-Spotify; if ((State).Status -eq 'Playing') { [void](Await ($s.TryPauseAsync()) ([bool])); Start-Sleep 1.5 } }
function Seek-To($seconds) { [void](Await ((Get-Spotify).TryChangePlaybackPositionAsync([long]($seconds * 1e7))) ([bool])) }
function Seek-Before-End($seconds) { Seek-To ((State).End - $seconds) }
function Launch($id) {
    Start-Process rundll32 -ArgumentList 'url.dll,FileProtocolHandler', "spotify:track:${id}?autoplay=true" -WindowStyle Hidden
}
function Wait-Until([scriptblock]$condition, [int]$seconds) {
    $until = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $until) { if (& $condition) { return $true }; Start-Sleep -Milliseconds 150 }
    return $false
}
function Start-Player([hashtable]$environment) {
    $environment.GetEnumerator() | ForEach-Object { Set-Item "env:$($_.Key)" $_.Value }
    Set-Item env:PLAYER_UI_PREVIEW 'failed'; Set-Item env:PLAYER_HUB_URL 'http://127.0.0.1:9'
    Start-Process -FilePath $Exe -PassThru
}
function Stop-Player($process) {
    Stop-Process $process -Force -ErrorAction SilentlyContinue
    Get-ChildItem env: | Where-Object { $_.Name -like 'PLAYER_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" }
}
function Log-Length { if (Test-Path $Log) { (Get-Item $Log).Length } else { 0 } }
function Log-Since($offset) {
    if (-not (Test-Path $Log)) { return '' }
    $stream = [IO.File]::Open($Log, 'Open', 'Read', 'ReadWrite'); $null = $stream.Seek($offset, 'Begin')
    $text = (New-Object IO.StreamReader $stream).ReadToEnd(); $stream.Dispose(); $text
}
function Wait-For-Log($offset, [string]$text, [int]$seconds) {
    Wait-Until { (Log-Since $offset) -match [regex]::Escape($text) } $seconds
}
function Park-At-End-Of($id) {
    # What a finished session leaves: the track paused in its last second.
    Launch $id; [void](Wait-Until { (State).Status -eq 'Playing' } 8); Start-Sleep 2
    Seek-Before-End 1; Start-Sleep 0.3; Pause-Spotify
}

$failures = @()
function Check($name, [bool]$ok, $detail = '') {
    if ($ok) { Write-Host ("  PASS  {0}" -f $name) } else { Write-Host ("  FAIL  {0}  {1}" -f $name, $detail); $script:failures += $name }
}
function Describe-State { $s = State; "{0} | {1} #{2} pos={3:N1}/{4:N1} shuffle={5} repeat={6}" -f $s.Status, $s.Title, $s.Number, $s.Pos, $s.End, $s.Shuffle, $s.Repeat }

function Scenario-End {
    Write-Host 'end: a commanded track is paused at its end and the next track never starts'
    Pause-Spotify; Launch $Album.t3[0]; [void](Wait-Until { (State).Status -eq 'Playing' } 8); Pause-Spotify
    $offset = Log-Length
    $player = Start-Player @{ PLAYER_DEV_PLAY = "spotify:track:$($Album.t2[0])"; PLAYER_DEV_TRACK = $Album.t2[1]; PLAYER_DEV_DURATION_MS = $Album.t2[2] }
    # Only once the player has verified the start: a jump to the middle of a track before that is a
    # resume to it, and it would put the track back at its beginning.
    [void](Wait-For-Log $offset 'guard armed' 15)
    Seek-Before-End 7
    $paused = Wait-Until { (State).Status -eq 'Paused' } 20
    $s = State; Stop-Player $player
    Check 'it paused' $paused (Describe-State)
    Check 'on the commanded track' ($s.Title -eq 'bad guy') $s.Title
    Check 'at its end' ($s.Pos -ge $s.End - 1.5) ("{0:N1}/{1:N1}" -f $s.Pos, $s.End)
}

function Scenario-FirstTrack {
    Write-Host 'first-track: the first track of an album that was just left is started, not resumed'
    Pause-Spotify; Park-At-End-Of $Album.t2[0]
    $player = Start-Player @{ PLAYER_DEV_PLAY = "spotify:track:$($Album.t1[0])"; PLAYER_DEV_TRACK = $Album.t1[1]; PLAYER_DEV_DURATION_MS = $Album.t1[2] }
    $ok = Wait-Until { $s = State; $s.Title -eq '!!!!!!!' -and $s.Status -eq 'Playing' -and $s.Pos -lt 4 } 15
    $s = State; Stop-Player $player; Pause-Spotify
    Check 'track 1 plays from its beginning' $ok (Describe-State)
}

function Scenario-OtherAlbum {
    Write-Host 'other-album: another album plays, the first track of an album left on track 4 is asked for'
    Pause-Spotify; Launch $Album.t4[0]; [void](Wait-Until { (State).Title -like 'you should*' } 8); Start-Sleep 2; Seek-To 25; Start-Sleep 3
    Launch $OtherAlbumTrack; [void](Wait-Until { (State).Title -like 'Speak To Me*' } 8); Start-Sleep 1; Seek-To 18; Start-Sleep 2
    $player = Start-Player @{ PLAYER_DEV_PLAY = "spotify:track:$($Album.t1[0])"; PLAYER_DEV_TRACK = $Album.t1[1]; PLAYER_DEV_DURATION_MS = $Album.t1[2] }
    $ok = Wait-Until { $s = State; $s.Title -eq '!!!!!!!' -and $s.Status -eq 'Playing' -and $s.Pos -lt 4 } 20
    $s = State; Stop-Player $player; Pause-Spotify
    Check 'track 1, not the album''s last track' $ok (Describe-State)
}

function Scenario-Shuffle {
    Write-Host 'shuffle: shuffle and repeat are turned off before the track is asked for'
    $s = Get-Spotify; Pause-Spotify
    [void](Await ($s.TryChangeShuffleActiveAsync($true)) ([bool])); Start-Sleep 1
    [void](Await ($s.TryChangeAutoRepeatModeAsync([Windows.Media.MediaPlaybackAutoRepeatMode]::Track)) ([bool])); Start-Sleep 1.5
    $before = Describe-State
    $player = Start-Player @{ PLAYER_DEV_PLAY = "spotify:track:$($Album.t2[0])"; PLAYER_DEV_TRACK = $Album.t2[1]; PLAYER_DEV_DURATION_MS = $Album.t2[2] }
    $ok = Wait-Until { $x = State; $x.Title -eq 'bad guy' -and $x.Status -eq 'Playing' -and $x.Shuffle -eq 'False' -and $x.Repeat -eq 'None' } 12
    Stop-Player $player; Pause-Spotify
    Check 'shuffle and repeat are off and the track plays' $ok ("before: $before | after: $(Describe-State)")
}

function Scenario-Restart {
    Write-Host 'restart: a song already playing when the player starts is guarded while a session runs'
    Pause-Spotify; Launch $Album.t2[0]; [void](Wait-Until { (State).Status -eq 'Playing' } 8); Start-Sleep 2; Seek-Before-End 12; Start-Sleep 1
    $player = Start-Player @{ PLAYER_DEV_SESSION = '1' }
    $paused = Wait-Until { (State).Status -eq 'Paused' } 20
    $s = State; Stop-Player $player
    Check 'it paused at its end' ($paused -and $s.Title -eq 'bad guy' -and $s.Pos -ge $s.End - 1.5) (Describe-State)
}

$scenarios = [ordered]@{ 'end' = ${function:Scenario-End}; 'first-track' = ${function:Scenario-FirstTrack}; 'other-album' = ${function:Scenario-OtherAlbum}; 'shuffle' = ${function:Scenario-Shuffle}; 'restart' = ${function:Scenario-Restart} }
if (-not (Get-Spotify)) { Write-Host 'Spotify is not running: start it and sign in.'; exit 2 }
$chosen = if ($Scenario -eq 'all') { $scenarios.Keys } else { @($Scenario) }
foreach ($name in $chosen) {
    if (-not $scenarios.Contains($name)) { Write-Host "unknown scenario '$name'"; exit 2 }
    & $scenarios[$name]
}
Pause-Spotify
if ($failures.Count -gt 0) { Write-Host ("`n{0} check(s) failed: {1}" -f $failures.Count, ($failures -join ', ')); exit 1 }
Write-Host "`nall checks passed"
