# RO 紅水提醒

這是一個只讀遊戲視窗的小工具：它定期直接擷取 RO 視窗中你指定的物品欄數字，低於門檻後播放 Windows 系統提示音。它**不會**對遊戲點擊、按鍵、買物品或改動任何遊戲資料。

## 使用方式

1. 開啟遊戲並打開物品欄，讓紅色藥水的數量清楚可見。
2. 雙擊 [啟動紅水提醒.cmd](./啟動紅水提醒.cmd)。
3. 第一次會出現校正視窗；按「確定」後，拖曳框選紅水的**數字**。框越緊、越不含圖示或文字，辨識會越好。
4. 預設每 5 秒讀一次，低於 200 瓶時每分鐘以系統音效提醒兩聲。視窗保持開著即可。
5. 要結束程式，回到黑色視窗按 `Ctrl+C`。

## 調整門檻或重選位置

在本資料夾空白處按 Shift + 右鍵，選「在此處開啟 PowerShell」，再輸入：

```powershell
.\ROPotionAlert.ps1 -Threshold 100
.\ROPotionAlert.ps1 -Calibrate
.\ROPotionAlert.ps1 -Threshold 100 -IntervalSeconds 3 -ReminderSeconds 30
```

每次變更會記錄在 `ROPotionAlert.config.json`。刪除該檔案後，下次啟動也會重新校正。

## 注意事項

- RO 可被其他視窗蓋住或在背景執行；程式會直接向 RO 視窗請求畫面，不使用桌面截圖。遊戲不能最小化，因為 Windows 不保證能渲染最小化的遊戲視窗。
- 若數字辨識不準，先以 `-Calibrate` 重框一次。可加上 `-SaveDebugImage`，它會輸出 `ROPotionAlert.last-read.png`，讓你檢查實際送去 OCR 的黑白影像。
- 遊戲的 UI 縮放、解析度、視窗位置改變後，都要重新校正。

## 起司提醒

RO 在這台電腦上以系統管理員權限執行，因此請雙擊 [以系統管理員啟動起司提醒.cmd](./以系統管理員啟動起司提醒.cmd)，並在 Windows 的 UAC 提示選「是」。第一次用滑鼠只框住左上角起司數量（例如 `248`）的數字。它有獨立的設定檔，不會和紅水的框選混在一起；預設低於 **30** 個時提醒。

若框錯，或遊戲的 UI 縮放／解析度改變，雙擊 [重新校正起司提醒.cmd](./重新校正起司提醒.cmd) 後再框一次；它同樣會要求 UAC 確認。

起司版會保留兩張最新的診斷圖片：`ROCheeseAlert.last-crop.png` 是遊戲視窗實際讀到的區域，`ROCheeseAlert.last-read.png` 是送往 OCR 的黑白放大圖。若顯示「看不出數字」，請提供這兩張圖。

啟動後會有一個小型常駐狀態窗，持續顯示起司數量與最後更新時間；正常數量為綠色、低於門檻為紅色、無法辨識則顯示黃色問號。

同一次啟動也會在 PowerShell 顯示手機監控網址。讓手機與電腦連到同一個 Wi-Fi，將該網址輸入手機瀏覽器即可查看即時數量。若 Windows 詢問是否允許網路存取，請由你確認並只允許「私人網路」。

## SAVECHAT 經驗計算

雙擊 [啟動SAVECHAT經驗計算.cmd](./啟動SAVECHAT經驗計算.cmd) 可以計算 `/savechat` 產生的經驗資料。程式會讀取 `C:\Gravity\RagnarokZero\Chat\Chat_經驗*.txt`，列出最近的 SAVEDATA；你先選擇要計算的結束點，再確認起點，換算 Base / Job EXP/hr。若輸入目前 Base 等級，會依內建 Lv1~79 升級需求表換算 Base %/hr。

如果多開 RO 並用不同帳號輸入 `/savechat`，檔名會共用同一組流水號。這時不要直接相信「自動前一筆」，請在起點選單手動選同帳號上一筆 SAVEDATA；也可以輸入帳號或角色備註，方便寫入 `SaveChatExpMeter.history.csv` 後回看。

若 RO 安裝在不同位置，可在 PowerShell 手動指定：

```powershell
.\SaveChatExpMeter.ps1 -ChatPath "D:\Gravity\RagnarokZero\Chat"
```

計算結果會追加到 `SaveChatExpMeter.history.csv`，方便之後回看各段效率。Base 經驗需求表參考 RO 樂園官網公告的等級需求優化方向，並取自 RO 樂園資訊站升級計算器目前公開的 Lv1~80 表。原始交接筆記已整理到 [docs/RO_EXP_METER_交接筆記.md](./docs/RO_EXP_METER_交接筆記.md)。

雙擊啟動檔計算完成後，程式會詢問是否清空 `Chat_*.txt`。只有輸入 `DELETE` 才會刪除；直接 Enter 會取消。刪除範圍限於指定 Chat 資料夾內的 `Chat_*.txt`，但如果多開帳號共用同一個 Chat 資料夾，所有帳號的 savechat 文字檔都會一起清掉。
