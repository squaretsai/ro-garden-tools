param(
  [Parameter(Mandatory = $true)]
  [string]$WorkbookPath,

  [string]$OutputDir = ".\aspd-workbook-dump"
)

$ErrorActionPreference = "Stop"

function Get-TextFromNode {
  param(
    [System.Xml.XmlNode]$Node,
    [System.Xml.XmlNamespaceManager]$NamespaceManager
  )

  if ($null -eq $Node) {
    return ""
  }

  $textNodes = $Node.SelectNodes(".//*[local-name()='t']", $NamespaceManager)
  if ($textNodes.Count -eq 0) {
    return $Node.InnerText
  }

  return (($textNodes | ForEach-Object { $_.InnerText }) -join "")
}

function Join-ZipPath {
  param(
    [string]$PackageRoot,
    [string]$BasePath,
    [string]$RelativePath
  )

  if ($RelativePath.StartsWith("/")) {
    $normalized = $RelativePath.TrimStart("/")
    return [System.IO.Path]::GetFullPath((Join-Path $PackageRoot $normalized))
  }

  $path = [System.IO.Path]::GetFullPath((Join-Path $BasePath $RelativePath))
  return $path
}

function Get-OptionalInnerText {
  param(
    [System.Xml.XmlNode]$Node
  )

  if ($null -eq $Node) {
    return ""
  }

  return $Node.InnerText
}

$resolvedWorkbook = Resolve-Path -LiteralPath $WorkbookPath
$workbookItem = Get-Item -LiteralPath $resolvedWorkbook
if ($workbookItem.Extension -ne ".xlsx") {
  throw "請提供 .xlsx 檔案，目前收到：$($workbookItem.FullName)"
}

$resolvedOutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$tempRoot = Join-Path $env:TEMP ("aspd-xlsx-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
Expand-Archive -LiteralPath $workbookItem.FullName -DestinationPath $tempRoot -Force

$workbookXmlPath = Join-Path $tempRoot "xl\workbook.xml"
$workbookRelsPath = Join-Path $tempRoot "xl\_rels\workbook.xml.rels"
if (!(Test-Path -LiteralPath $workbookXmlPath) -or !(Test-Path -LiteralPath $workbookRelsPath)) {
  throw "這個 xlsx 裡沒有標準 workbook.xml，可能不是有效的 Excel 匯出檔。"
}

[xml]$workbookXml = Get-Content -LiteralPath $workbookXmlPath -Raw -Encoding UTF8
[xml]$workbookRelsXml = Get-Content -LiteralPath $workbookRelsPath -Raw -Encoding UTF8

$ns = New-Object System.Xml.XmlNamespaceManager($workbookXml.NameTable)
$ns.AddNamespace("main", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
$ns.AddNamespace("r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")

$relsById = @{}
foreach ($rel in $workbookRelsXml.SelectNodes("//*[local-name()='Relationship']")) {
  $relsById[$rel.Id] = $rel.Target
}

$sharedStrings = @()
$sharedStringPath = Join-Path $tempRoot "xl\sharedStrings.xml"
if (Test-Path -LiteralPath $sharedStringPath) {
  [xml]$sharedStringXml = Get-Content -LiteralPath $sharedStringPath -Raw -Encoding UTF8
  $sharedNs = New-Object System.Xml.XmlNamespaceManager($sharedStringXml.NameTable)
  $sharedNs.AddNamespace("main", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
  foreach ($si in $sharedStringXml.SelectNodes("//*[local-name()='si']", $sharedNs)) {
    $sharedStrings += (Get-TextFromNode -Node $si -NamespaceManager $sharedNs)
  }
}

$definedNames = @()
foreach ($definedName in $workbookXml.SelectNodes("//*[local-name()='definedName']", $ns)) {
  $definedNames += [pscustomobject]@{
    name          = $definedName.name
    localSheetId  = $definedName.localSheetId
    hidden        = $definedName.hidden
    comment       = $definedName.comment
    refersTo      = $definedName.InnerText
  }
}

$sheets = @()
$allCells = @()
$formulas = @()
$validations = @()

foreach ($sheetNode in $workbookXml.SelectNodes("//*[local-name()='sheet']", $ns)) {
  $relationshipId = $sheetNode.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
  $target = $relsById[$relationshipId]
  if ([string]::IsNullOrWhiteSpace($target)) {
    continue
  }

  $sheetPath = Join-ZipPath -PackageRoot $tempRoot -BasePath (Join-Path $tempRoot "xl") -RelativePath $target
  if (!(Test-Path -LiteralPath $sheetPath)) {
    continue
  }

  [xml]$sheetXml = Get-Content -LiteralPath $sheetPath -Raw -Encoding UTF8
  $sheetNs = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
  $sheetNs.AddNamespace("main", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")

  $sheetInfo = [pscustomobject]@{
    name     = $sheetNode.name
    sheetId  = $sheetNode.sheetId
    state    = $sheetNode.state
    target   = $target
    path     = $sheetPath
  }
  $sheets += $sheetInfo

  foreach ($cellNode in $sheetXml.SelectNodes("//*[local-name()='c']", $sheetNs)) {
    $cellRef = $cellNode.r
    $cellType = $cellNode.t
    $formulaNode = $cellNode.SelectSingleNode("./*[local-name()='f']", $sheetNs)
    $valueNode = $cellNode.SelectSingleNode("./*[local-name()='v']", $sheetNs)
    $inlineNode = $cellNode.SelectSingleNode("./*[local-name()='is']", $sheetNs)
    $rawValue = if ($null -ne $valueNode) { $valueNode.InnerText } else { "" }
    $displayValue = $rawValue

    if ($cellType -eq "s" -and $rawValue -match "^\d+$") {
      $index = [int]$rawValue
      if ($index -ge 0 -and $index -lt $sharedStrings.Count) {
        $displayValue = $sharedStrings[$index]
      }
    } elseif ($cellType -eq "inlineStr") {
      $displayValue = Get-TextFromNode -Node $inlineNode -NamespaceManager $sheetNs
    }

    $cell = [pscustomobject]@{
      sheet        = $sheetNode.name
      cell         = $cellRef
      type         = $cellType
      rawValue     = $rawValue
      displayValue = $displayValue
      formula      = if ($null -ne $formulaNode) { $formulaNode.InnerText } else { "" }
      formulaType  = if ($null -ne $formulaNode) { $formulaNode.t } else { "" }
      style        = $cellNode.s
    }
    $allCells += $cell
    if (![string]::IsNullOrWhiteSpace($cell.formula)) {
      $formulas += $cell
    }
  }

  foreach ($validationNode in $sheetXml.SelectNodes("//*[local-name()='dataValidation']", $sheetNs)) {
    $validations += [pscustomobject]@{
      sheet     = $sheetNode.name
      sqref     = $validationNode.sqref
      type      = $validationNode.type
      operator  = $validationNode.operator
      allowBlank = $validationNode.allowBlank
      formula1  = Get-OptionalInnerText -Node ($validationNode.SelectSingleNode("./*[local-name()='formula1']", $sheetNs))
      formula2  = Get-OptionalInnerText -Node ($validationNode.SelectSingleNode("./*[local-name()='formula2']", $sheetNs))
    }
  }
}

$result = [pscustomobject]@{
  sourceWorkbook = $workbookItem.FullName
  extractedAt    = (Get-Date).ToString("s")
  sheets         = $sheets
  definedNames   = $definedNames
  dataValidations = $validations
  formulas       = $formulas
  cells          = $allCells
}

$jsonPath = Join-Path $resolvedOutputDir "aspd-workbook-dump.json"
$formulaCsvPath = Join-Path $resolvedOutputDir "aspd-formulas.csv"
$cellCsvPath = Join-Path $resolvedOutputDir "aspd-cells.csv"
$sheetCsvPath = Join-Path $resolvedOutputDir "aspd-sheets.csv"
$validationCsvPath = Join-Path $resolvedOutputDir "aspd-validations.csv"

$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$formulas | Export-Csv -LiteralPath $formulaCsvPath -Encoding UTF8 -NoTypeInformation
$allCells | Export-Csv -LiteralPath $cellCsvPath -Encoding UTF8 -NoTypeInformation
$sheets | Export-Csv -LiteralPath $sheetCsvPath -Encoding UTF8 -NoTypeInformation
$validations | Export-Csv -LiteralPath $validationCsvPath -Encoding UTF8 -NoTypeInformation

Write-Host "已解析：$($workbookItem.FullName)"
Write-Host "分頁數：$($sheets.Count)"
Write-Host "公式數：$($formulas.Count)"
Write-Host "儲存格數：$($allCells.Count)"
Write-Host "輸出資料夾：$resolvedOutputDir"
Write-Host "公式 CSV：$formulaCsvPath"
