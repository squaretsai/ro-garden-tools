param(
    [string]$ChatPath = "C:\Gravity\RagnarokZero\Chat",
    [int]$List = 20,
    [string]$MapName = "",
    [switch]$NoHistory
)

try {
    [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
} catch {
}

function Format-Number {
    param([double]$Value)
    return ("{0:N0}" -f $Value)
}

function Read-ChatText {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encodings = @()
    $encodings += New-Object System.Text.UTF8Encoding($false, $true)
    try { $encodings += [System.Text.Encoding]::GetEncoding(950) } catch {}
    $encodings += [System.Text.Encoding]::Default
    $encodings += [System.Text.Encoding]::Unicode

    foreach ($encoding in $encodings) {
        try {
            $text = $encoding.GetString($bytes)
            if ($text -match "經驗|傷害|取得|將") {
                return $text
            }
        } catch {
        }
    }

    return [System.Text.Encoding]::Default.GetString($bytes)
}

function Get-CheckpointTime {
    param([Parameter(Mandatory)]$File)

    if ($File.LastWriteTime -gt [datetime]"1980-01-01") {
        return $File.LastWriteTime
    }

    return $File.CreationTime
}

function Get-ExpStats {
    param([Parameter(Mandatory)][string]$Path)

    $text = Read-ChatText -Path $Path
    $baseExp = [int64]0
    $jobExp = [int64]0
    $pattern = "將'(?<amount>[\d,]+)'的(?<job>職業)?經驗值獲得"

    foreach ($match in [regex]::Matches($text, $pattern)) {
        $amount = [int64](($match.Groups["amount"].Value) -replace ",", "")
        if ($match.Groups["job"].Success -and $match.Groups["job"].Value) {
            $jobExp += $amount
        } else {
            $baseExp += $amount
        }
    }

    [pscustomobject]@{
        BaseExp = $baseExp
        JobExp = $jobExp
        Lines = ([regex]::Matches($text, $pattern)).Count
    }
}

function Get-SaveChatSuffix {
    param([Parameter(Mandatory)][string]$FileName)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    if ($name -match "^Chat_經驗(?<suffix>_\d+)?$") {
        return $Matches["suffix"]
    }

    return ""
}

function Get-CompanionFiles {
    param(
        [Parameter(Mandatory)][string]$Suffix,
        [Parameter(Mandatory)][string[]]$Names
    )

    $files = @()
    foreach ($name in $Names) {
        $path = Join-Path $ChatPath ("{0}{1}.txt" -f $name, $Suffix)
        if (Test-Path -LiteralPath $path) {
            $files += Get-Item -LiteralPath $path
        }
    }

    return $files
}

function Get-MonsterStats {
    param([System.IO.FileInfo[]]$Files)

    $stats = @{}
    foreach ($file in $Files) {
        $text = Read-ChatText -Path $file.FullName
        foreach ($match in [regex]::Matches($text, "向\[(?<name>[^\]]+)\]給予'(?<damage>[\d,]+)'的傷害")) {
            $name = $match.Groups["name"].Value.Trim()
            $damage = [int64](($match.Groups["damage"].Value) -replace ",", "")
            if (-not $stats.ContainsKey($name)) {
                $stats[$name] = [pscustomobject]@{ Name = $name; Hits = 0; Damage = [int64]0 }
            }
            $stats[$name].Hits += 1
            $stats[$name].Damage += $damage
        }
    }

    return $stats.Values | Sort-Object Hits, Damage -Descending | Select-Object -First 5
}

function Get-DropStats {
    param([System.IO.FileInfo[]]$Files)

    $stats = @{}
    foreach ($file in $Files) {
        $text = Read-ChatText -Path $file.FullName
        foreach ($match in [regex]::Matches($text, "取得\s+(?<name>.+?)\s+(?<count>\d+)\s+個")) {
            $name = $match.Groups["name"].Value.Trim()
            $count = [int64]$match.Groups["count"].Value
            if (-not $stats.ContainsKey($name)) {
                $stats[$name] = [pscustomobject]@{ Name = $name; Count = [int64]0 }
            }
            $stats[$name].Count += $count
        }
    }

    return $stats.Values | Sort-Object Count -Descending | Select-Object -First 8
}

if (-not (Test-Path -LiteralPath $ChatPath)) {
    Write-Host "找不到 Chat 資料夾：$ChatPath" -ForegroundColor Red
    Write-Host "可用方式：.\SaveChatExpMeter.ps1 -ChatPath 'C:\Gravity\RagnarokZero\Chat'"
    exit 1
}

$expFiles = Get-ChildItem -LiteralPath $ChatPath -Filter "Chat_經驗*.txt" -File |
    Sort-Object @{ Expression = { Get-CheckpointTime $_ } }, Name

if (-not $expFiles -or $expFiles.Count -eq 0) {
    Write-Host "目前沒有找到 Chat_經驗*.txt。請先在遊戲內輸入 /savechat。" -ForegroundColor Yellow
    exit 0
}

$start = [Math]::Max(0, $expFiles.Count - $List)
$rows = @()
for ($i = $start; $i -lt $expFiles.Count; $i++) {
    $current = $expFiles[$i]
    $previous = if ($i -gt 0) { $expFiles[$i - 1] } else { $null }
    $currentTime = Get-CheckpointTime $current
    $previousTime = if ($previous) { Get-CheckpointTime $previous } else { $null }
    $elapsed = if ($previous) { $currentTime - $previousTime } else { $null }

    $rows += [pscustomobject]@{
        No = $rows.Count + 1
        SourceIndex = $i
        File = $current
        PreviousFile = $previous
        Time = $currentTime
        PreviousTime = $previousTime
        Elapsed = $elapsed
    }
}

Write-Host ""
Write-Host "可選擇的 SAVEDATA / savechat 時段" -ForegroundColor Cyan
Write-Host "編號  結束時間              經驗檔案                 自動起點"
Write-Host "----  -------------------   ----------------------   -------------------"
foreach ($row in $rows) {
    $prevText = if ($row.PreviousTime) { $row.PreviousTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "無前一筆" }
    Write-Host ("{0,4}  {1}   {2,-22}   {3}" -f $row.No, $row.Time.ToString("yyyy-MM-dd HH:mm:ss"), $row.File.Name, $prevText)
}

$defaultNo = $rows[-1].No
$choiceText = Read-Host "輸入要計算的編號，直接 Enter 使用最新一筆 [$defaultNo]"
$choice = 0
if ([string]::IsNullOrWhiteSpace($choiceText)) {
    $choice = $defaultNo
} elseif (-not [int]::TryParse($choiceText, [ref]$choice)) {
    Write-Host "編號格式不正確。" -ForegroundColor Red
    exit 1
}

$selected = $rows | Where-Object { $_.No -eq $choice } | Select-Object -First 1
if (-not $selected) {
    Write-Host "找不到編號 $choice。" -ForegroundColor Red
    exit 1
}

if (-not $MapName) {
    $MapName = Read-Host "地圖名稱，可直接 Enter 略過"
}

$exp = Get-ExpStats -Path $selected.File.FullName
$elapsedSeconds = if ($selected.Elapsed) { [Math]::Max(0, [int][Math]::Round($selected.Elapsed.TotalSeconds)) } else { 0 }
$basePerHour = if ($elapsedSeconds -gt 0) { $exp.BaseExp / $elapsedSeconds * 3600 } else { 0 }
$jobPerHour = if ($elapsedSeconds -gt 0) { $exp.JobExp / $elapsedSeconds * 3600 } else { 0 }
$suffix = Get-SaveChatSuffix -FileName $selected.File.Name
$battleFiles = Get-CompanionFiles -Suffix $suffix -Names @("Chat_戰鬥", "Chat_戰鬥訊息")
$dropFiles = Get-CompanionFiles -Suffix $suffix -Names @("Chat_一般訊息", "Chat_一般")
$monsterStats = Get-MonsterStats -Files $battleFiles
$dropStats = Get-DropStats -Files $dropFiles

Write-Host ""
Write-Host "EXP Meter 結果" -ForegroundColor Green
Write-Host ("SAVEDATA：{0}" -f $selected.File.Name)
if ($selected.PreviousFile) {
    Write-Host ("自動起點：{0} ({1})" -f $selected.PreviousFile.Name, $selected.PreviousTime.ToString("yyyy-MM-dd HH:mm:ss"))
} else {
    Write-Host "自動起點：無前一筆，無法計算每小時效率" -ForegroundColor Yellow
}
Write-Host ("結束時間：{0}" -f $selected.Time.ToString("yyyy-MM-dd HH:mm:ss"))
if ($elapsedSeconds -gt 0) {
    Write-Host ("經過時間：{0:hh\:mm\:ss} ({1:N0} 秒)" -f ([timespan]::FromSeconds($elapsedSeconds)), $elapsedSeconds)
}
if ($MapName) {
    Write-Host ("地圖：{0}" -f $MapName)
}
Write-Host ("Base EXP：{0}" -f (Format-Number $exp.BaseExp))
Write-Host ("Job EXP ：{0}" -f (Format-Number $exp.JobExp))
Write-Host ("Base EXP/hr：{0}" -f (Format-Number $basePerHour))
Write-Host ("Job EXP/hr ：{0}" -f (Format-Number $jobPerHour))

if ($monsterStats) {
    Write-Host ""
    Write-Host "本段主要怪物"
    foreach ($monster in $monsterStats) {
        Write-Host ("- {0}: {1} hit / {2} damage" -f $monster.Name, (Format-Number $monster.Hits), (Format-Number $monster.Damage))
    }
}

if ($dropStats) {
    Write-Host ""
    Write-Host "本段掉落物"
    foreach ($drop in $dropStats) {
        Write-Host ("- {0}: {1}" -f $drop.Name, (Format-Number $drop.Count))
    }
}

if (-not $NoHistory) {
    $historyPath = Join-Path $PSScriptRoot "SaveChatExpMeter.history.csv"
    [pscustomobject]@{
        Savedata = $selected.File.Name
        PreviousSavedata = if ($selected.PreviousFile) { $selected.PreviousFile.Name } else { "" }
        StartedAt = if ($selected.PreviousTime) { $selected.PreviousTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
        EndedAt = $selected.Time.ToString("yyyy-MM-dd HH:mm:ss")
        ElapsedSeconds = $elapsedSeconds
        MapName = $MapName
        BaseExp = $exp.BaseExp
        JobExp = $exp.JobExp
        BaseExpPerHour = [int64][Math]::Round($basePerHour)
        JobExpPerHour = [int64][Math]::Round($jobPerHour)
    } | Export-Csv -LiteralPath $historyPath -Append -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host ("已記錄到：{0}" -f $historyPath)
}


