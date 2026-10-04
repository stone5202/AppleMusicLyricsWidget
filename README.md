# AppleMusicLyricsWidget

在 iPhone 的動態島、鎖定畫面與主畫面小工具上，同步顯示 Apple Music 正在播放歌曲的歌詞。

目前版本：**1.0.0**（版本紀錄見 [CHANGELOG.md](CHANGELOG.md)）

## 功能

- **即時動態**：在動態島與鎖定畫面逐行顯示歌詞，一次顯示目前句與後兩句，置中排版；切到其他 App 或鎖定螢幕後仍會持續更新，換歌也會跟上。
- **小工具**：主畫面小、中尺寸，以及鎖定畫面的長方形小工具；小尺寸也可用於待機模式與 CarPlay。每個小工具可各自調整歌詞提早或延後的秒數。
- **App 內歌詞**：顯示目前句與後五句，並可控制播放、上一首、下一首。
- **歌詞時間調整**：App 與即時動態的歌詞可提早或延後最多 10 秒，每次 0.5 秒，設定會保存。
- **多個歌詞來源**：同時查詢 LRCLIB、酷狗音樂、網易雲音樂，採用第一個有時間軸的結果；都沒有時才顯示不會動的一般歌詞。
- **簡體轉繁體**：裝置語言為繁體中文時，簡體歌詞會自動轉成繁體。

## 系統需求

- iOS 26 以上的 iPhone（動態島需要 iPhone 14 Pro 以後的機型）
- Xcode 26 以上
- Apple Music 訂閱，並使用系統內建的「音樂」App 播放

## 安裝

1. 用 Xcode 開啟 `AppleMusicLyricsWidget.xcodeproj`。
2. 在 App 與 Widget 兩個 target 選擇你的 Development Team。
3. Bundle ID 預設為 `com.yuchen.AppleMusicLyricsWidget`，App Group 為 `group.com.yuchen.AppleMusicLyricsWidget`。若你的帳號無法使用，請修改 `project.yml` 與 `Shared/AppConstants.swift`，再執行 `xcodegen generate`。
4. 接上 iPhone，選為執行目標後執行。

### 免費的 Personal Team

免費帳號的描述檔不支援 App Group，建置時需要清空 entitlements：

```sh
xcodebuild -project AppleMusicLyricsWidget.xcodeproj \
  -scheme AppleMusicLyricsWidget \
  -destination 'id=<你的裝置 UDID>' \
  -derivedDataPath /tmp/AppleMusicLyricsWidget-DerivedData \
  DEVELOPMENT_TEAM=<你的 Team ID> CODE_SIGN_ENTITLEMENTS= \
  -allowProvisioningUpdates build
```

沒有 App Group 時，小工具會自行讀取目前歌曲並抓取歌詞。DerivedData 請放在 iCloud 同步資料夾以外的位置，否則簽章可能失敗。

### 修改專案設定

專案檔由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 產生。新增檔案或修改 `project.yml` 後，執行 `xcodegen generate` 重新產生。

## 使用方式

1. 開啟 App，允許取用 Apple Music。
2. 在「音樂」App 播放歌曲。
3. 回到 App 按「開始」啟動即時動態。
4. 依 App 內提示，到系統設定把本 App 的「位置」改為「永遠」（原因見下一節）。
5. 小工具：在主畫面或鎖定畫面加入「同步歌詞」。長按小工具選「編輯小工具」可調整歌詞時間。

## 背景更新的運作方式

iOS 不允許 App 在背景建立即時動態，而且會拒絕「只在播放背景媒體」的 App 更新即時動態（更新不會報錯，但內容不會變）。本 App 在即時動態開啟期間做兩件事來維持更新：

- **播放靜音音訊**：讓 App 在背景持續執行。使用混音模式，不會中斷 Apple Music。
- **最低精度的背景定位**：讓系統不再把 App 視為「只在播放背景媒體」。位置資料完全不讀取、不儲存、不上傳。

定位只在權限為「永遠」時才啟動。權限為「使用 App 期間」時，系統會在動態島顯示定位指示而蓋住歌詞，所以這種情況下 App 不會使用定位，即時動態也只在 App 位於前景時更新。

為了省電，App 在背景時會睡到下一句歌詞才醒來（播放中最長 2 秒、暫停時 3 秒檢查一次）。

這個做法是為個人使用設計的，不太可能通過 App Store 審核。正規做法是 ActivityKit 推播，需要付費開發者帳號與推播伺服器。

## 已知限制

- 歌詞換句是盡力而為，不保證與歌聲完全同步；可用時間調整功能微調。
- 小工具的更新時機由 WidgetKit 決定。App 完全停止時發生的換歌，要等系統下次讓小工具執行才會反映。
- 即時動態最長存活 8 小時，結束後需回到 App 重新啟動。
- 重新安裝 App 會清掉現有的即時動態。
- 簡體轉繁體是自動轉換，偶爾會有錯字。

## 歌詞來源與聲明

| 來源 | 說明 |
|---|---|
| [LRCLIB](https://lrclib.net) | 公開 API，西洋與日韓歌曲較齊全 |
| 酷狗音樂 | 非官方介面，華語歌曲齊全 |
| 網易雲音樂 | 非官方介面，華語、日韓、西洋皆有 |
| [lyrics.ovh](https://lyrics.ovh) | 僅一般歌詞，最後備援 |

Apple Music 本身的歌詞沒有公開 API，無法取用。酷狗與網易雲為非官方介面，對方改版時可能失效。歌詞著作權屬於各權利人；本專案僅供個人學習與使用，若要散布或商用，請自行確認各服務條款與歌詞授權。

本專案與 Apple、LRCLIB、酷狗、網易雲皆無關聯。

## 專案結構

- `App/`：主 App、MusicKit 播放監看、即時動態管理與背景維持
- `Shared/`：資料模型、LRC 解析、歌詞來源、配色、App 與小工具共用狀態
- `Widget/`：小工具與即時動態的畫面
- `project.yml`：XcodeGen 專案定義
