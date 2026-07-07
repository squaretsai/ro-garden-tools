param(
    [int]$BaseLevel = 0,
    [double]$StartPercent = -1,
    [double]$EndPercent = -1,
    [string]$StartTime = "",
    [string]$EndTime = "",
    [int64]$ManualBaseExpToNext = 0,
    [string]$MapName = "",
    [string]$AccountName = "",
    [switch]$NoHistory
)

function Format-Number {
    param([double]$Value)
    return ("{0:N0}" -f $Value)
}

function Format-Percent {
    param([double]$Value)
    return ("{0:N2}%" -f $Value)
}

function Convert-PercentInput {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $normalized = $Text.Trim() -replace "%", ""
    $value = 0.0
    if ([double]::TryParse($normalized, [ref]$value)) {
        return $value
    }

    return $null
}

function Convert-TimeInput {
    param(
        [string]$Text,
        [datetime]$BaseDate
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $normalized = $Text.Trim() -replace "::", ":"
    if ($normalized -match "^(?<hour>\d{1,2}):(?<minute>\d{1,2})(:(?<second>\d{1,2}))?$") {
        $hour = [int]$Matches["hour"]
        $minute = [int]$Matches["minute"]
        $second = if ($Matches["second"]) { [int]$Matches["second"] } else { 0 }
        if ($hour -lt 24 -and $minute -lt 60 -and $second -lt 60) {
            return $BaseDate.Date.AddHours($hour).AddMinutes($minute).AddSeconds($second)
        }
    }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($normalized, [ref]$parsed)) {
        return $parsed
    }

    return $null
}

$script:BaseExpTableSource = "使用者提供的 RO樂園 BaseLv1~99 需求經驗表截圖；目前公開整理至 Lv99。"
$script:BaseExpToNextByLevel = @{
    1 = 2443
    2 = 2711
    3 = 3009
    4 = 3339
    5 = 3706
    6 = 4113
    7 = 4565
    8 = 5067
    9 = 5624
    10 = 6242
    11 = 6928
    12 = 7690
    13 = 8535
    14 = 9473
    15 = 10515
    16 = 11671
    17 = 12954
    18 = 14378
    19 = 15959
    20 = 17714
    21 = 19662
    22 = 21824
    23 = 24224
    24 = 26888
    25 = 29845
    26 = 33127
    27 = 36770
    28 = 40814
    29 = 45303
    30 = 50286
    31 = 55817
    32 = 61956
    33 = 68771
    34 = 76335
    35 = 84731
    36 = 94051
    37 = 104396
    38 = 115879
    39 = 128625
    40 = 142773
    41 = 158478
    42 = 175910
    43 = 195260
    44 = 216738
    45 = 240579
    46 = 267042
    47 = 296416
    48 = 329021
    49 = 365213
    50 = 434603
    51 = 1037509
    52 = 1525139
    53 = 2241953
    54 = 3295672
    55 = 4844639
    56 = 7121618
    57 = 10468780
    58 = 15389107
    59 = 22621987
    60 = 25789065
    61 = 29399534
    62 = 33515469
    63 = 38207635
    64 = 43556704
    65 = 49654642
    66 = 56606292
    67 = 64531173
    68 = 73565537
    69 = 83864712
    70 = 94767124
    71 = 107086850
    72 = 121008141
    73 = 136739199
    74 = 154515294
    75 = 174602283
    76 = 197300579
    77 = 222949654
    78 = 251933109
    79 = 284684413
    80 = 318846542
    81 = 357108127
    82 = 399961102
    83 = 447956434
    84 = 501711206
    85 = 561916551
    86 = 629346536
    87 = 704868120
    88 = 789452294
    89 = 884186569
    90 = 1061023882
    91 = 1273228658
    92 = 1527874389
    93 = 1833449266
    94 = 2200139119
    95 = 2640166942
    96 = 3168200330
    97 = 3801840396
    98 = 4562208475
}

if ($BaseLevel -le 0) {
    $baseLevelText = Read-Host "目前 Base 等級（不是 Job 等級）"
    if (-not [int]::TryParse($baseLevelText, [ref]$BaseLevel)) {
        Write-Host "Base 等級格式不正確。" -ForegroundColor Red
        exit 1
    }
}

$baseExpToNext = $null
if ($script:BaseExpToNextByLevel.ContainsKey($BaseLevel)) {
    $baseExpToNext = [double]$script:BaseExpToNextByLevel[$BaseLevel]
} else {
    $maxSupportedBaseLevel = ($script:BaseExpToNextByLevel.Keys | Measure-Object -Maximum).Maximum
    Write-Host ("目前內建 Base 經驗表支援 Lv1~{0}；Lv{1} 需要手動輸入升下一級需求經驗。" -f $maxSupportedBaseLevel, $BaseLevel) -ForegroundColor Yellow
    if ($ManualBaseExpToNext -le 0) {
        $manualExpText = Read-Host ("手動輸入 Lv{0} -> Lv{1} 需求經驗" -f $BaseLevel, ($BaseLevel + 1))
        $manualExpText = $manualExpText -replace ",", ""
        if (-not [int64]::TryParse($manualExpText, [ref]$ManualBaseExpToNext) -or $ManualBaseExpToNext -le 0) {
            Write-Host "手動需求經驗格式不正確。" -ForegroundColor Red
            exit 1
        }
    }

    $baseExpToNext = [double]$ManualBaseExpToNext
}

if ($StartPercent -lt 0) {
    $parsedStart = Convert-PercentInput (Read-Host "起始 Base %（例 82.8）")
    if ($null -eq $parsedStart) {
        Write-Host "起始 Base % 格式不正確。" -ForegroundColor Red
        exit 1
    }
    $StartPercent = $parsedStart
}

if ($EndPercent -lt 0) {
    $parsedEnd = Convert-PercentInput (Read-Host "結束 Base %（例 86.5）")
    if ($null -eq $parsedEnd) {
        Write-Host "結束 Base % 格式不正確。" -ForegroundColor Red
        exit 1
    }
    $EndPercent = $parsedEnd
}

$startedAt = Convert-TimeInput $StartTime ([datetime]::Today)
while ($null -eq $startedAt) {
    $startedAt = Convert-TimeInput (Read-Host "起始時間（例 10:21 或 22:21）") ([datetime]::Today)
    if ($null -eq $startedAt) {
        Write-Host "起始時間格式不正確。" -ForegroundColor Yellow
    }
}

$endedAt = Convert-TimeInput $EndTime ([datetime]::Today)
while ($null -eq $endedAt) {
    $endedAt = Convert-TimeInput (Read-Host "結束時間（例 10:37 或 22:37）") ([datetime]::Today)
    if ($null -eq $endedAt) {
        Write-Host "結束時間格式不正確。" -ForegroundColor Yellow
    }
}

if ($endedAt -lt $startedAt) {
    $endedAt = $endedAt.AddDays(1)
}

if (-not $MapName) {
    $MapName = Read-Host "地圖名稱，可直接 Enter 略過"
}

if (-not $AccountName) {
    $AccountName = Read-Host "帳號或角色備註，可直接 Enter 略過"
}

$elapsedSeconds = [Math]::Max(0, [int][Math]::Round(($endedAt - $startedAt).TotalSeconds))
if ($elapsedSeconds -le 0) {
    Write-Host "時間差為 0，無法計算。" -ForegroundColor Red
    exit 1
}

$percentDelta = $EndPercent - $StartPercent
if ($percentDelta -lt 0) {
    $percentDelta += 100
}

$percentPerHour = $percentDelta / $elapsedSeconds * 3600
$baseExp = $percentDelta / 100 * $baseExpToNext
$baseExpPerHour = $percentPerHour / 100 * $baseExpToNext

Write-Host ""
Write-Host "百分比 EXP Meter 結果" -ForegroundColor Green
Write-Host ("Base Lv{0} 升級需求：{1}" -f $BaseLevel, (Format-Number $baseExpToNext))
Write-Host ("Base %：{0:N2}% -> {1:N2}%（+{2:N2}%）" -f $StartPercent, $EndPercent, $percentDelta)
Write-Host ("時間：{0} -> {1}" -f $startedAt.ToString("HH:mm:ss"), $endedAt.ToString("HH:mm:ss"))
Write-Host ("經過時間：{0:hh\:mm\:ss} ({1:N0} 秒)" -f ([timespan]::FromSeconds($elapsedSeconds)), $elapsedSeconds)
if ($MapName) {
    Write-Host ("地圖：{0}" -f $MapName)
}
if ($AccountName) {
    Write-Host ("帳號/角色：{0}" -f $AccountName)
}
Write-Host ("Base %/hr：{0}" -f (Format-Percent $percentPerHour))
Write-Host ("等效 Base EXP：{0}" -f (Format-Number $baseExp))
Write-Host ("等效 Base EXP/hr：{0}" -f (Format-Number $baseExpPerHour))
Write-Host ("計算：{0:N2}% / {1:N0} 秒 * 3600" -f $percentDelta, $elapsedSeconds)

if (-not $NoHistory) {
    $historyPath = Join-Path $PSScriptRoot "BasePercentExpMeter.history.csv"
    [pscustomobject]@{
        StartedAt = $startedAt.ToString("yyyy-MM-dd HH:mm:ss")
        EndedAt = $endedAt.ToString("yyyy-MM-dd HH:mm:ss")
        ElapsedSeconds = $elapsedSeconds
        AccountName = $AccountName
        MapName = $MapName
        BaseLevel = $BaseLevel
        BaseExpToNext = [int64]$baseExpToNext
        StartPercent = $StartPercent
        EndPercent = $EndPercent
        PercentDelta = [Math]::Round($percentDelta, 4)
        BasePercentPerHour = [Math]::Round($percentPerHour, 4)
        BaseExp = [int64][Math]::Round($baseExp)
        BaseExpPerHour = [int64][Math]::Round($baseExpPerHour)
    } | Export-Csv -LiteralPath $historyPath -Append -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host ("已記錄到：{0}" -f $historyPath)
}

