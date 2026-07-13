# shift-hours

A shift calculator PWA, installable on an iPhone home screen. Answers two questions:

1. **Am I still legally allowed to work?** — a student visa (資格外活動許可) caps you at **28 hours in any 7 consecutive days**. Not Mon–Sun. This app checks the real rolling window.
2. **What will I get paid?** — hourly rate bands (regular / night), unpaid breaks, optional holiday rate.

Works offline. No server, no account, no data leaves the phone.

---

## The 28-hour rule, done properly

The limit is **not** "Monday to Sunday ≤ 28h". It is: pick *any* day, look at that day plus the next six — that stretch must not exceed 28 hours. A schedule can look perfectly legal week by week and still break the law:

```
        Thu Fri Sat Sun │ Mon Tue Wed Thu
hours    5   5   5   5  │  5   5   5   5
        ── week 1: 20h ─┼── week 2: 20h ──   both "fine"
             └──── 7 consecutive days = 35h ────┘   ILLEGAL
```

Every day cell shows how many more hours you can still take (`+3.5`), computed as the tightest of the seven rolling windows that contain that day. If a shift you add breaks the limit, the app says so immediately.

Hours are counted **after** the unpaid break, and are attributed to the day the shift **starts** — so a 21:00–02:00 shift counts entirely against its start date.

---

## Pay

Hourly **rate bands** covering the full 24h, editable in ⚙️. Defaults:

| Time | ¥/h |
|------|-----|
| 00:00 – 06:00 | 1420 |
| 06:00 – 22:00 | 1140 |
| 22:00 – 24:00 | 1420 |

Every minute is priced by the band it actually falls in, so an 18:00–24:00 shift is **4h regular + 2h night**, not one or the other. Shifts running past midnight are priced correctly across the boundary.

- **Breaks** — auto-deducted per 労基法34条: 45 min once a shift passes 6h, 60 min once it passes 8h. Removed from both pay and the 28h count, spread proportionally across the bands the shift spans. Override per shift, or turn off in ⚙️.
- **Holiday rate** — optional. Set a ¥/h in ⚙️, then tick "Holiday rate" on a shift to pay the whole thing at that rate instead of the bands. Leave it blank to ignore holidays entirely.

---

## Jobs

Several employers, each with their own rate bands (⚙️ → Jobs). Pay is worked out per job;
**the 28-hour limit is the total across all of them**, which is how immigration counts it.

## Adding shifts

| Button | Action |
|--------|--------|
| `＋` | Add one by hand — **Start & end**, or **Just hours** |
| `📷` | Photo of the shift table — OCR reads the dates and times |
| `📝` | **Paste from work, or type quickly** |
| `⏰` | Export to the iPhone Calendar with an alarm |
| `⚙️` | Name, limit, breaks, jobs and rates |

### Quick typing

For a month you have already worked, times are a waste of keystrokes. Type hours:

```
18 -> 3                      3 hours on the 18th
19 -> 4
18: 3 family mart, 4 lamu    two jobs in one day
22 = 5n                      5 hours at the night rate
```

The day is in the month you are looking at. `3h`, `3 hours`, `3時間` all work; `at` is optional.

An hours-only entry has no clock, so the app cannot tell which hours were late — it pays the
job's **regular** rate unless you add `n` (or tick "night rate"). No break is deducted either;
the hours you type are taken as hours actually worked. Enter start and end times when you want
the night split and the break rule applied properly.

The paste parser reads the format work actually sends:

```
▢2026/07/23 (木) 13:00〜18:00 豊橋野依インター ▢2026/07/24 (金) 11:00〜15:30 豊橋野依インター
```

All on one line or one per line; with or without the year; `〜` `~` `～` `-` as the separator; `00:00` as an end time means midnight. It scans for date+time patterns rather than splitting on the bullet, so it does not care which box character is used.

---

## Alarms before a shift

**A web app cannot set an alarm on iOS.** No browser can schedule a notification for a future time, and web push would need a server. Anything scheduled in JavaScript only fires while the app is open on screen — useless for waking you up.

So `⏰` hands the shifts to the **iPhone Calendar**, which *can* alarm. Download the `.ics`, tap **Add All**, and iOS notifies you 20 minutes before every shift (configurable, plus an optional second earlier alert).

Re-export whenever shifts change — each shift keeps a stable UID, so re-importing **updates** the event instead of duplicating it.

---

## Files

```
shift-hours/
├── index.html     # the whole app — HTML + CSS + JS
├── sw.js          # service worker, offline cache
├── manifest.json  # PWA metadata
├── icon.png       # home screen icon
└── README.md
```

## Not losing the data

Shifts live in `localStorage` on the phone. **Deploying new code cannot delete them** — the app and
the data are different things in different places, and a new `index.html` overwrites the app only.

The real hazard is a future version that *misreads* the data, starts up with an empty list, and then
saves that emptiness over the top. So:

- **A read failure never becomes an empty save.** If the stored shifts can't be parsed, the app sets
  a broken flag, `save()` refuses to write anything, and a red banner tells you to restore. The bytes
  stay on disk for a fix. (The old code did `catch { shifts = [] }` and would have overwritten them.)
- **Rolling snapshots** (last 12) under their own key that migrations never touch — taken on every
  open, and before an import, a migration, or Delete all.
- **⚙️ → Backups** lists them with date and shift count. Restore snapshots the current state first,
  so a restore is itself undoable.
- A full disk is reported, not swallowed.

⚙️ → **Copy all data** / **Paste & import** still moves everything between Safari and the installed
app (separate storage), or to a new phone. That is the only off-device copy — snapshots live on the
same phone, so they survive a bad deploy but not a lost phone.

---

## Hosting

Push to GitHub, then **Settings → Pages → Source: `main` / root**. Open the Pages URL on the iPhone in Safari → Share → **Add to Home Screen**.

After changing `index.html`, bump the cache version in `sw.js` (`shifthours-vN` → `vN+1`) or the phone will keep serving the old copy.

---

## Accounts & cloud sync (optional)

Off by default. With it off, the app is local-only and nothing leaves the phone.

To turn it on, create a free [Supabase](https://supabase.com) project, run `supabase-schema.sql`
in its SQL Editor, then fill in the `CLOUD` block near the top of the `<script>` in `index.html`:

```js
const CLOUD = {
  url:     'https://xxxxxxxx.supabase.co',
  anonKey: 'eyJhbGci...'
};
```

The anon key is *meant* to be public — it grants nothing by itself. Every table is behind
**Row Level Security**, so Postgres refuses to return one user's rows to another. That guarantee
lives in the database, not in this JavaScript, so a frontend bug cannot leak anyone's hours.

Once configured, a 👤 button appears. Sign in and shifts sync across devices; the app stays
local-first and keeps working offline. Sync **merges** rather than overwrites: each shift carries
the time it was last edited and the newer side wins, and deletions travel as tombstones so a shift
removed on one phone doesn't get resurrected by another.

**If you let other people sign up, you are holding their data** — and it is the record of whether
they have exceeded their 28-hour visa limit. Keep the circle small, and under Japan's 個人情報保護法
(APPI) be ready to delete someone's data on request (`delete from auth.users where email = ...`
cascades to everything they own).
