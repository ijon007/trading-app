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
| `Share/` | The P&L share card |
| `Profile/` | Settings, Face ID, passcode, appearance |
| `Onboarding/` | First-run flow |
| `Components/` | Shared pieces: `PrivacyMode`, `AppLock`, `Sparkline`, `CoinIcon`, `Dropdown`, and so on |
| `Models/` | All data and state (see below) |

## Data
- **Live market data** is in `Models/MarketData.swift` (`MarketStore`, `@Observable`). It has no API keys and is free.
  - The Coinbase WebSocket `wss://ws-feed.exchange.coinbase.com` provides live prices.
  - Coinbase `/products/{id}/candles` provides the chart history.
  - CoinGecko `/coins/markets` provides the top 100 coins with names, logos, market cap, volume, supply, ATH and rank. CoinGecko is rate-limited, so cache it and don't poll it fast.
  - Don't use Binance, because it blocks US users.
- **Accounts** are in `Models/Accounts.swift` (`AccountStore`). A wallet *is* an account, so there are no separate "wallets". Accounts are kept in UserDefaults and support selected and default accounts, plus watch-only accounts (`isWatchOnly`, `address`).
- **Watch-only** is in `Models/EthereumWatch.swift`. It reads ETH plus a fixed list of top tokens through `ethereum-rpc.publicnode.com` and resolves `.eth` names. It covers Ethereum only.
- **Keys** are in `Models/WalletService.swift`, which is currently a `MockWalletService` storing phrases in UserDefaults. **That's a mock only.** Real keys must go in the Keychain behind Face ID, and the first version should run on the Sepolia testnet.
- `Watchlist.swift` holds starred coins in UserDefaults. `SampleData.swift` and `ActivityData.swift` hold sample amounts, transactions and cost basis.
- Buying, selling and sending are UI only right now, and nothing goes on-chain.

## Design rules
- Always use `Theme`, `Space`, `Radius` and the `Typography` styles. Never use raw colors, magic numbers or system fonts directly.
- Keep it grayscale. Color only means something: green for up, red for down. Charts get a gradient area fill (22% opacity at the top, fading to clear).
- Follow Apple's design guidelines, use native components first, and add subtle spring animations and haptics on actions.
- Keep spacing tight. Sheets and drawers size themselves to their content (content-height detent), so there's no dead space.
- Wrap every money amount in privacy mode (the `PrivacyMode` modifier). Percentages stay visible.
- Keep it simple: no extra screens or flows when a row, swipe or drawer will do. Default timeframe is **1H** everywhere.
- Check on a real phone before calling UI done.

## Working rules
- Make small, focused commits, one per change, with clear messages. Commit as you go.
- Several agents work in this repo, so only stage your own hunks and don't rewrite someone else's commits.
- Don't push unless Jon asks. Never force-push.
