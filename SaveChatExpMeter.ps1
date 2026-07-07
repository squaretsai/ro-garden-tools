param(
    [string]$ChatPath = "C:\Gravity\RagnarokZero\Chat",
    [int]$List = 20,
    [string]$MapName = "",
    [string]$AccountName = "",
    [int]$BaseLevel = 0,
    [int64]$ManualBaseExpToNext = 0,
    [switch]$AskDeleteChat,
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

function Format-Percent {
    param([double]$Value)
    return ("{0:N2}%" -f $Value)
}

$script:BaseExpTableSource = "巴哈姆特 RO樂園升級經驗值調整紀錄：第四次(2026/01/13)，目前公開整理至 Lv90。"
$script:BaseExpToNextByLevel = @{
    1 = 2443
    2 = 2736
    3 = 3064
    4 = 3431
    5 = 3842
    6 = 4303
    7 = 4819
    8 = 5397
    9 = 6044
    10 = 6769
    11 = 7581
    12 = 8490
    13 = 9508
    14 = 10648
    15 = 11925
    16 = 13356
    17 = 14958
    18 = 16752
    19 = 18762
    20 = 21013
    21 = 23534
    22 = 26358
    23 = 29520
    24 = 33062
    25 = 37029
    26 = 41472
    27 = 46448
    28 = 52021
    29 = 58263
    30 = 65254
    31 = 73084
    32 = 81854
    33 = 91676
    34 = 102677
    35 = 114998
    36 = 128797
    37 = 144252
    38 = 161562
    39 = 180949
    40 = 202662
    41 = 226981
    42 = 254218
    43 = 284724
    44 = 318890
    45 = 357156
    46 = 400014
    47 = 448015
    48 = 501776
    49 = 561989
    50 = 680006
    51 = 1482156
    52 = 2178770
    53 = 3202791
    54 = 4708104
    55 = 6920913
    56 = 10173741
    57 = 14955400
    58 = 21984439
    59 = 32317125
    60 = 36841522
    61 = 41999335
    62 = 47879242
    63 = 54582336
    64 = 62223863
    65 = 70935204
    66 = 80866132
    67 = 92187391
    68 = 105093625
    69 = 119806732
    70 = 135381607
    71 = 152981215
    72 = 172868773
    73 = 195341713
    74 = 220736135
    75 = 249431833
    76 = 281857970
    77 = 318499506
    78 = 359904442
    79 = 406692019
    80 = 455495061
    81 = 510154468
    82 = 571373004
    83 = 639937764
    84 = 716730295
    85 = 802737930
    86 = 899066481
    87 = 1006954458
    88 = 1127788992
    89 = 1263123671
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

function Invoke-ChatCleanupPrompt {
    param([Parameter(Mandatory)][string]$TargetPath)

    $chatFiles = Get-ChildItem -LiteralPath $TargetPath -Filter "Chat_*.txt" -File -ErrorAction SilentlyContinue
    if (-not $chatFiles -or $chatFiles.Count -eq 0) {
        Write-Host ""
        Write-Host "Chat 資料夾目前沒有 Chat_*.txt 可刪除。"
        return
    }

    Write-Host ""
    Write-Host ("清空 Chat 檔案：找到 {0} 個 Chat_*.txt" -f $chatFiles.Count) -ForegroundColor Yellow
    Write-Host ("目標資料夾：{0}" -f $TargetPath)
    Write-Host "這會刪除所有 savechat 文字檔；如果多開帳號共用同一個 Chat 資料夾，也會一起清掉。"
    $confirmDelete = Read-Host "若確定要刪除，請輸入 DELETE；直接 Enter 取消"

    if ($confirmDelete -ne "DELETE") {
        Write-Host "已取消刪除 Chat 檔案。"
        return
    }

    $deleted = 0
    foreach ($file in $chatFiles) {
        Remove-Item -LiteralPath $file.FullName -Force
        $deleted += 1
    }

    Write-Host ("已刪除 {0} 個 Chat 檔案。" -f $deleted) -ForegroundColor Green
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

$allRows = @()
for ($i = 0; $i -lt $expFiles.Count; $i++) {
    $current = $expFiles[$i]
    $previous = if ($i -gt 0) { $expFiles[$i - 1] } else { $null }
    $currentTime = Get-CheckpointTime $current
    $previousTime = if ($previous) { Get-CheckpointTime $previous } else { $null }
    $elapsed = if ($previous) { $currentTime - $previousTime } else { $null }

    $allRows += [pscustomobject]@{
        No = $i + 1
        SourceIndex = $i
        File = $current
        PreviousFile = $previous
        Time = $currentTime
        PreviousTime = $previousTime
        Elapsed = $elapsed
    }
}

$rows = $allRows | Select-Object -Last $List

Write-Host ""
Write-Host "可選擇的 SAVEDATA / savechat 時段" -ForegroundColor Cyan
Write-Host "編號  結束時間              經驗檔案                 自動前一筆"
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

$selected = $allRows | Where-Object { $_.No -eq $choice } | Select-Object -First 1
if (-not $selected) {
    Write-Host "找不到編號 $choice。" -ForegroundColor Red
    exit 1
}

$defaultStart = if ($selected.SourceIndex -gt 0) { $allRows[$selected.SourceIndex - 1] } else { $null }
$startCandidates = $allRows |
    Where-Object { $_.SourceIndex -lt $selected.SourceIndex } |
    Select-Object -Last $List

if ($startCandidates) {
    Write-Host ""
    Write-Host "可選擇的起點 SAVEDATA" -ForegroundColor Cyan
    Write-Host "多開不同帳號時，請選同帳號上一筆；直接 Enter 使用自動前一筆。"
    Write-Host "編號  起點時間              經驗檔案"
    Write-Host "----  -------------------   ----------------------"
    foreach ($row in $startCandidates) {
        Write-Host ("{0,4}  {1}   {2}" -f $row.No, $row.Time.ToString("yyyy-MM-dd HH:mm:ss"), $row.File.Name)
    }
}

$startPoint = $defaultStart
if ($defaultStart) {
    $startChoiceText = Read-Host "輸入起點編號，直接 Enter 使用 [$($defaultStart.No)] $($defaultStart.File.Name)"
    if (-not [string]::IsNullOrWhiteSpace($startChoiceText)) {
        $startChoice = 0
        if (-not [int]::TryParse($startChoiceText, [ref]$startChoice)) {
            Write-Host "起點編號格式不正確。" -ForegroundColor Red
            exit 1
        }

        $manualStart = $allRows | Where-Object { $_.No -eq $startChoice } | Select-Object -First 1
        if (-not $manualStart) {
            Write-Host "找不到起點編號 $startChoice。" -ForegroundColor Red
            exit 1
        }

        if ($manualStart.SourceIndex -ge $selected.SourceIndex) {
            Write-Host "起點必須早於結束點。" -ForegroundColor Red
            exit 1
        }

        $startPoint = $manualStart
    }
} else {
    Write-Host "這是第一筆 SAVEDATA，沒有可用起點，無法計算每小時效率。" -ForegroundColor Yellow
}

if (-not $MapName) {
    $MapName = Read-Host "地圖名稱，可直接 Enter 略過"
}

if (-not $AccountName) {
    $AccountName = Read-Host "帳號或角色備註，可直接 Enter 略過"
}

if ($BaseLevel -le 0) {
    $baseLevelText = Read-Host "目前 Base 等級，可直接 Enter 略過 %/hr"
    if (-not [string]::IsNullOrWhiteSpace($baseLevelText)) {
        $parsedBaseLevel = 0
        if (-not [int]::TryParse($baseLevelText, [ref]$parsedBaseLevel)) {
            Write-Host "Base 等級格式不正確，略過 %/hr。" -ForegroundColor Yellow
        } else {
            $BaseLevel = $parsedBaseLevel
        }
    }
}

$baseExpToNext = $null
if ($BaseLevel -gt 0) {
    if ($script:BaseExpToNextByLevel.ContainsKey($BaseLevel)) {
        $baseExpToNext = [double]$script:BaseExpToNextByLevel[$BaseLevel]
    } else {
        $maxSupportedBaseLevel = ($script:BaseExpToNextByLevel.Keys | Measure-Object -Maximum).Maximum
        Write-Host ("目前內建 Base 經驗表支援 Lv1~{0}；Lv{1} 無法換算 %/hr。" -f $maxSupportedBaseLevel, $BaseLevel) -ForegroundColor Yellow
        Write-Host ("資料來源：{0}" -f $script:BaseExpTableSource) -ForegroundColor Yellow
        if ($ManualBaseExpToNext -le 0) {
            $manualExpText = Read-Host ("可手動輸入 Lv{0} -> Lv{1} 需求經驗以換算 %/hr，直接 Enter 略過" -f $BaseLevel, ($BaseLevel + 1))
            if (-not [string]::IsNullOrWhiteSpace($manualExpText)) {
                $manualExpText = $manualExpText -replace ",", ""
                $parsedManualBaseExp = [int64]0
                if ([int64]::TryParse($manualExpText, [ref]$parsedManualBaseExp) -and $parsedManualBaseExp -gt 0) {
                    $ManualBaseExpToNext = $parsedManualBaseExp
                } else {
                    Write-Host "手動需求經驗格式不正確，略過 %/hr。" -ForegroundColor Yellow
                }
            }
        }

        if ($ManualBaseExpToNext -gt 0) {
            $baseExpToNext = [double]$ManualBaseExpToNext
        }
    }
}

$exp = Get-ExpStats -Path $selected.File.FullName
$elapsed = if ($startPoint) { $selected.Time - $startPoint.Time } else { $null }
$elapsedSeconds = if ($elapsed) { [Math]::Max(0, [int][Math]::Round($elapsed.TotalSeconds)) } else { 0 }
$basePerHour = if ($elapsedSeconds -gt 0) { $exp.BaseExp / $elapsedSeconds * 3600 } else { 0 }
$jobPerHour = if ($elapsedSeconds -gt 0) { $exp.JobExp / $elapsedSeconds * 3600 } else { 0 }
$basePercentPerHour = if ($baseExpToNext -and $baseExpToNext -gt 0) { $basePerHour / $baseExpToNext * 100 } else { $null }
$suffix = Get-SaveChatSuffix -FileName $selected.File.Name
$battleFiles = Get-CompanionFiles -Suffix $suffix -Names @("Chat_戰鬥", "Chat_戰鬥訊息")
$dropFiles = Get-CompanionFiles -Suffix $suffix -Names @("Chat_一般訊息", "Chat_一般")
$monsterStats = Get-MonsterStats -Files $battleFiles
$dropStats = Get-DropStats -Files $dropFiles

Write-Host ""
Write-Host "EXP Meter 結果" -ForegroundColor Green
Write-Host ("SAVEDATA：{0}" -f $selected.File.Name)
if ($startPoint) {
    $startLabel = if ($defaultStart -and $startPoint.No -eq $defaultStart.No) { "起點" } else { "手動起點" }
    Write-Host ("{0}：{1} ({2})" -f $startLabel, $startPoint.File.Name, $startPoint.Time.ToString("yyyy-MM-dd HH:mm:ss"))
} else {
    Write-Host "起點：無前一筆，無法計算每小時效率" -ForegroundColor Yellow
}
Write-Host ("結束時間：{0}" -f $selected.Time.ToString("yyyy-MM-dd HH:mm:ss"))
if ($elapsedSeconds -gt 0) {
    Write-Host ("經過時間：{0:hh\:mm\:ss} ({1:N0} 秒)" -f ([timespan]::FromSeconds($elapsedSeconds)), $elapsedSeconds)
}
if ($MapName) {
    Write-Host ("地圖：{0}" -f $MapName)
}
if ($AccountName) {
    Write-Host ("帳號/角色：{0}" -f $AccountName)
}
Write-Host ("Base EXP：{0}" -f (Format-Number $exp.BaseExp))
Write-Host ("Job EXP ：{0}" -f (Format-Number $exp.JobExp))
Write-Host ("Base EXP/hr：{0}" -f (Format-Number $basePerHour))
Write-Host ("Job EXP/hr ：{0}" -f (Format-Number $jobPerHour))
if ($baseExpToNext) {
    Write-Host ("Base Lv{0} 升級需求：{1}" -f $BaseLevel, (Format-Number $baseExpToNext))
    Write-Host ("Base %/hr：{0}" -f (Format-Percent $basePercentPerHour))
}

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
        PreviousSavedata = if ($startPoint) { $startPoint.File.Name } else { "" }
        StartedAt = if ($startPoint) { $startPoint.Time.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
        EndedAt = $selected.Time.ToString("yyyy-MM-dd HH:mm:ss")
        ElapsedSeconds = $elapsedSeconds
        AccountName = $AccountName
        MapName = $MapName
        BaseLevel = if ($baseExpToNext) { $BaseLevel } else { "" }
        BaseExpToNext = if ($baseExpToNext) { [int64]$baseExpToNext } else { "" }
        BaseExp = $exp.BaseExp
        JobExp = $exp.JobExp
        BaseExpPerHour = [int64][Math]::Round($basePerHour)
        JobExpPerHour = [int64][Math]::Round($jobPerHour)
        BasePercentPerHour = if ($baseExpToNext) { [Math]::Round($basePercentPerHour, 4) } else { "" }
    } | Export-Csv -LiteralPath $historyPath -Append -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host ("已記錄到：{0}" -f $historyPath)
}

if ($AskDeleteChat) {
    Invoke-ChatCleanupPrompt -TargetPath $ChatPath
}

