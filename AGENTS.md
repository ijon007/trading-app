# Updraft

Native SwiftUI iOS crypto wallet. It's built on Windows + WSL Ubuntu with **xtool** (no Mac, no Xcode). The feel is high-end finance: calm, minimal, grayscale, Liquid Glass. Read this file before you change anything.

## Build & run
- Pure SwiftPM only (`Package.swift`, iOS 26). Don't add an Xcode project, CocoaPods, or binary/xcframework dependencies, because xtool can't build them. Any new package must compile as plain Swift source on Linux.
- To build to the phone, keep iTunes open on Windows and the iPhone plugged in and unlocked, then run this from `~/Updraft`:
  ```
  . ~/.local/share/swiftly/env.sh
  export USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"
  xtool dev
  ```
- The app config lives in `xtool.yml`: bundle ID `com.ijon007.Updraft` and `iconPath: Resources/AppIcon.png`. The icon is a single PNG of white bars on black. xtool can't do dark or tinted icon variants.
- Signing is a free Apple account, so you can't use push notifications, Sign in with Apple (the button is UI only), or App Groups and extensions such as widgets and Live Activities. The Keychain, Face ID and local notifications all work.

## Layout (`Sources/Updraft/`)
| Folder | What's in it |
|---|---|
| `UpdraftApp.swift`, `RootView.swift` | App entry and the tab bar: Home (custom Updraft-mark icon), Explore, Profile |
| `Theme/` | `Theme.swift` (colors, glass), `Tokens.swift` (`Space`, `Radius`), `Typography.swift`, `GlassButton.swift`, `Haptics.swift`, `Appearance.swift` |
| `Home/` | `HomeView`, `PortfolioChart`, the account pill (`AccountSwitcher`) and the bottom `AccountsDrawer` |
| `Explore/` | Market list, search, and the top gainers marquee |
| `CoinDetail/` | The coin sheet: chart, timeframes, stats, and the watchlist star |
| `Trade/`, `Transfer/` | Buy and sell, plus Send, Receive, Swap, internal transfers, and `HoldToConfirm` |
| `Accounts/` | Add-account sheet (Create / Import / Watch), wallet creation with phrase backup, and the empty state |
| `Share/` | `PnLCard.swift` (the card, plus `UpdraftLogoShape`, the traced logo stripes) and `PnLShareSheet.swift` (timeframe, light/dark and hide-amounts options; `ImageRenderer` + `ShareLink`) |
| `Profile/` | Settings, Face ID, passcode, appearance |
| `Onboarding/` | First-run flow |
| `Components/` | Shared pieces: `PrivacyMode`, `AppLock`, `Sparkline`, `CoinIcon`, `Dropdown`, and so on |
| `Models/` | All data and state (see below) |

## Data
- **Live market data** (`Models/MarketData.swift`, `MarketStore`, `@Observable`). No API keys.
  - Coinbase Exchange WebSocket `ticker` on `wss://ws-feed.exchange.coinbase.com` for live prices and 24h open; ticks buffer and flush to UI at most once per second.
  - Coinbase REST `https://api.exchange.coinbase.com/products/{id}/candles` for chart history (paged).
  - CoinGecko `GET /coins/markets` (top 100 by market cap, ~every 60s) for names, logos, market cap, volume, supply, ATH, rank, and as a price fallback when the socket is down. Non-Coinbase coins use CoinGecko `market_chart` for candles.
  - Don't use Binance (blocks US users).
- **Accounts** (`Models/Accounts.swift`, `AccountStore`). A wallet *is* an account. UserDefaults keys: `accounts.saved.v2` (full ordered list; legacy `accounts.saved.v1` still read), `account.current` (last selected), `account.default` (fallback when the selected account is gone). Supports rename/reorder, transfer between own accounts (`Account.transfer`; watch-only can't be the source), and watch-only (`isWatchOnly`, `address` — can't send/swap). UI: `Home/AccountsDrawer` (tap switcher to bottom drawer; swipe delete / set default; Add account).
- **Watch-only** (`Models/EthereumWatch.swift`). Batched JSON-RPC to `https://ethereum-rpc.publicnode.com`: `eth_getBalance` (ETH) plus ERC-20 `balanceOf` for USDC, USDT, WBTC, LINK, UNI, SHIB, DAI, PEPE. ENS via `https://api.ensideas.com/ens/resolve/...`. Ethereum only.
- **Keys** (`Models/WalletService.swift`): `WalletService` protocol; app uses `MockWalletService`. Phrases live in plain UserDefaults as `wallet.mock.phrase.{accountID}` — not Keychain. Fake addresses; no real keys. Demo app passcode is `123456` (`Profile/PasscodeView`, `Components/AppLock`). Real keys must go in Keychain behind Face ID; first on-chain version should be Sepolia.
- **Other persistence**: `watchlist.v1` (`Watchlist.swift`), `currency`, `privacy.hideAmounts`, `send.recipients.v1`. `SampleData.swift` / `ActivityData.swift` hold sample amounts, transactions and cost basis.
- Buy, sell and send are UI-only demos (send sleeps ~1s and marks sent); nothing goes on-chain.

## Design rules
- **Tokens:** every color, spacing, radius and font comes from `Theme`, `Space`, `Radius` and `Typo`. Match how existing screens style the same thing before inventing a new style. No raw hex colors or magic numbers.
- **Color:** grayscale. Color only means something: `Theme.positive` for up, `Theme.negative` for down. Charts get a gradient area fill (22% opacity at the top, fading to clear).
- **Liquid Glass sparingly:** only on floating or interactive controls (glass buttons via `GlassButton.swift`, the account pill, bottom action bars). Content cards use `Theme.surface`, not glass.
- **Native first:** use native components, but for choosing between options inside a sheet use the custom `Components/Dropdown.swift` instead of a native `Menu`.
- **No all-caps labels** (don't use `.eyebrow()`, which uppercases) and **no tile backgrounds behind icons**: icons sit bare.
- **Dismissal:** tapping empty space dismisses the keyboard (`KeyboardDismissal`, installed once on the window) and closes drawers.
- **Sheets fit their content:** measure the content and use a `.height` detent (see `AddAccountSheet`), so nothing clips and there's no dead space. Keep spacing tight.
- **Defaults:** charts open on **1H** (Home and coin detail). The P&L share card opens on **1D**.
- **Empty states:** an account with no assets hides the balance chart and change, and shows `EmptyAccountView` (bare symbol, one line, one action).
- **Privacy:** wrap every money amount in `.privateAmount()` (`PrivacyMode`, stored under `privacy.hideAmounts`). Percentages stay visible.
- **Motion and haptics:** subtle springs that can be interrupted, and haptics per the conventions in `Theme/Haptics.swift`.
- Keep it simple: no extra screens or flows when a row, swipe or drawer will do.
- Don't restyle UI Jon has approved unless asked. Check edge cases (empty, long text, keyboard, privacy on) on a real phone before calling UI done.

## Working rules
- Make small, focused commits, one per change, with clear messages. Commit as you go.
- Several agents work in this repo, so only stage your own hunks and don't rewrite someone else's commits.
- Don't push unless Jon asks. Never force-push.
