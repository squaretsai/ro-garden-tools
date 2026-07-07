# RO EXP Meter 交接筆記

## 目前確認到的遊戲資料夾

- 遊戲路徑：`C:\Gravity\RagnarokZero`
- `/savechat` 會輸出到：`C:\Gravity\RagnarokZero\Chat`

## `/savechat` 行為

- 這是客戶端內建指令，來源確認於：
  `C:\Gravity\RagnarokZero\System\tipbox.lub`
- 指令說明：
  `/savechat` 會將聊天內容儲存為檔案。
- 實測後會依聊天分頁輸出多個檔案，例如：
  - `Chat_一般訊息.txt`
  - `Chat_戰鬥.txt`
  - `Chat_戰鬥訊息.txt`
  - `Chat_經驗.txt`
  - 第二次會變成 `Chat_經驗_001.txt`

## 經驗檔格式

經驗檔有乾淨的 Base / Job EXP 訊息：

```text
將'17778'的經驗值獲得
將'3555'的職業經驗值獲得
```

- Base EXP：`將'數字'的經驗值獲得`
- Job EXP：`將'數字'的職業經驗值獲得`
- 檔案內沒有逐行時間戳。
- 可使用檔案建立時間 / 修改時間當作 `/savechat` checkpoint。

## 已實測數據

第一次 `/savechat`：

- 時間：`2026-07-07 16:02:07`
- 檔案：`Chat_經驗.txt`
- Base EXP：`402,814`
- Job EXP：`80,551`

第二次 `/savechat`：

- 時間：`2026-07-07 17:27:23`
- 檔案：`Chat_經驗_001.txt`
- Base EXP：`2,693,378`
- Job EXP：`538,596`
- 間隔：約 `1 小時 25 分 16 秒`
- 換算：
  - Base EXP/hr：約 `1,894,947`
  - Job EXP/hr：約 `378,933`

## 計算公式

```text
Base EXP/hr = Base EXP / 經過秒數 * 3600
Job EXP/hr  = Job EXP  / 經過秒數 * 3600
```

## 戰鬥檔可提供的資訊

`Chat_戰鬥_001.txt` 會記錄怪物名稱和傷害，例如：

```text
向[夢魘]給予'2867'的傷害
向[綠腐屍]給予'4899'的傷害
```

所以未來程式可額外統計「本段主要怪物」。

## 一般訊息檔可提供的資訊

`Chat_一般訊息_001.txt` 會記錄道具取得，例如：

```text
取得 南瓜頭 1 個
取得 亡者牙齒 1 個
```

所以未來程式可額外統計「本段掉落物」。

## 目前沒有自動取得的資訊

- 地圖名稱
- 座標
- 每一筆經驗的精確時間

建議第一版程式讓使用者手動輸入地圖名稱。

## 建議程式規劃

第一版做「手動打點式 EXP Meter」：

1. 使用者按 `/savechat` 建立起點。
2. 掛機一段時間。
3. 使用者再按 `/savechat`。
4. 程式偵測最新 `Chat_經驗*.txt`。
5. 加總 Base / Job EXP。
6. 用兩次 savechat 的時間差換算 EXP/hr。
7. 顯示：
   - 本段 Base EXP
   - 本段 Job EXP
   - 本段 Base EXP/hr
   - 本段 Job EXP/hr
   - 本場累積
   - 主要怪物
   - 主要掉落物

## 注意事項

- `/savechat` 不是持續寫入 log，而是每次輸出一批聊天 buffer。
- 如果太久才按一次，聊天 buffer 可能被洗掉，會低估 EXP。
- 建議先每 5 到 10 分鐘按一次 `/savechat` 測試穩定間隔。
