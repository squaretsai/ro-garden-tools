/**
 * Google Sheets 原生匯出工具。
 *
 * 使用方式：
 * 1. 打開目標 Google 試算表。
 * 2. 如果不是你自己的表，先「檔案 > 建立副本」。
 * 3. 到「擴充功能 > Apps Script」。
 * 4. 貼上這整份程式，執行 exportWorkbookForCodex。
 * 5. 授權後，它會在同一個 Google Drive 資料夾產生一份 JSON 檔。
 * 6. 下載那份 JSON 給 Codex，就能比對原生公式，不經過 Excel 轉換。
 */
function exportWorkbookForCodex() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const spreadsheetFile = DriveApp.getFileById(ss.getId());
  const parentFolders = spreadsheetFile.getParents();
  const outputFolder = parentFolders.hasNext() ? parentFolders.next() : DriveApp.getRootFolder();
  const timezone = ss.getSpreadsheetTimeZone();

  const workbook = {
    exportedAt: new Date().toISOString(),
    spreadsheetId: ss.getId(),
    spreadsheetName: ss.getName(),
    spreadsheetUrl: ss.getUrl(),
    locale: ss.getSpreadsheetLocale(),
    timezone,
    namedRanges: exportNamedRanges_(ss),
    sheets: ss.getSheets().map(exportSheet_)
  };

  const fileName = `${ss.getName()} - codex-export.json`;
  const blob = Utilities.newBlob(
    JSON.stringify(workbook, null, 2),
    "application/json",
    fileName
  );

  const existingFiles = outputFolder.getFilesByName(fileName);
  while (existingFiles.hasNext()) {
    existingFiles.next().setTrashed(true);
  }

  const outputFile = outputFolder.createFile(blob);
  Logger.log(`匯出完成：${outputFile.getUrl()}`);
  SpreadsheetApp.getUi().alert(
    "Codex 匯出完成",
    `已建立 JSON：\n${outputFile.getUrl()}`,
    SpreadsheetApp.getUi().ButtonSet.OK
  );
}

function exportNamedRanges_(ss) {
  return ss.getNamedRanges().map(namedRange => ({
    name: namedRange.getName(),
    rangeA1: namedRange.getRange().getA1Notation(),
    sheetName: namedRange.getRange().getSheet().getName()
  }));
}

function exportSheet_(sheet) {
  const range = sheet.getDataRange();
  const rowCount = range.getNumRows();
  const columnCount = range.getNumColumns();
  const values = range.getValues();
  const displayValues = range.getDisplayValues();
  const formulas = range.getFormulas();
  const formulasR1C1 = range.getFormulasR1C1();
  const notes = range.getNotes();
  const backgrounds = range.getBackgrounds();
  const fontWeights = range.getFontWeights();
  const horizontalAlignments = range.getHorizontalAlignments();
  const numberFormats = range.getNumberFormats();
  const validations = range.getDataValidations();

  const cells = [];
  for (let row = 0; row < rowCount; row += 1) {
    for (let col = 0; col < columnCount; col += 1) {
      const formula = formulas[row][col] || "";
      const displayValue = displayValues[row][col] || "";
      const rawValue = normalizeValue_(values[row][col]);
      const note = notes[row][col] || "";
      const validation = validations[row][col];

      if (
        formula === "" &&
        displayValue === "" &&
        note === "" &&
        validation === null
      ) {
        continue;
      }

      cells.push({
        a1: toA1_(row + 1, col + 1),
        row: row + 1,
        column: col + 1,
        rawValue,
        displayValue,
        formula,
        formulaR1C1: formulasR1C1[row][col] || "",
        note,
        dataValidation: exportValidation_(validation),
        style: {
          background: backgrounds[row][col],
          fontWeight: fontWeights[row][col],
          horizontalAlignment: horizontalAlignments[row][col],
          numberFormat: numberFormats[row][col]
        }
      });
    }
  }

  return {
    name: sheet.getName(),
    sheetId: sheet.getSheetId(),
    index: sheet.getIndex(),
    hidden: sheet.isSheetHidden(),
    maxRows: sheet.getMaxRows(),
    maxColumns: sheet.getMaxColumns(),
    frozenRows: sheet.getFrozenRows(),
    frozenColumns: sheet.getFrozenColumns(),
    dataRangeA1: range.getA1Notation(),
    rowCount,
    columnCount,
    cells
  };
}

function exportValidation_(validation) {
  if (!validation) {
    return null;
  }

  const criteriaType = validation.getCriteriaType();
  const criteriaValues = validation.getCriteriaValues().map(normalizeValidationValue_);
  return {
    criteriaType: String(criteriaType),
    criteriaValues,
    allowInvalid: validation.getAllowInvalid(),
    helpText: validation.getHelpText()
  };
}

function normalizeValidationValue_(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (
    value &&
    typeof value.getA1Notation === "function" &&
    typeof value.getSheet === "function"
  ) {
    return {
      type: "Range",
      sheetName: value.getSheet().getName(),
      a1: value.getA1Notation()
    };
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (Array.isArray(value)) {
    return value.map(normalizeValidationValue_);
  }

  return value;
}

function normalizeValue_(value) {
  if (value instanceof Date) {
    return value.toISOString();
  }
  return value;
}

function toA1_(row, column) {
  let col = column;
  let letters = "";
  while (col > 0) {
    const remainder = (col - 1) % 26;
    letters = String.fromCharCode(65 + remainder) + letters;
    col = Math.floor((col - 1) / 26);
  }
  return `${letters}${row}`;
}
