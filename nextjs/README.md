# Codemon Speedrun Leaderboard API (Next.js)

This folder provides a drop-in API route for the **Codemon** speedrun leaderboard and completion log synchronization.

---

## 1. Quick Setup in Next.js App Router

1. In your Next.js project directory, navigate to:
   ```
   app/api/leaderboard/
   ```
2. Copy `route.ts` into that folder:
   ```
   app/api/leaderboard/route.ts
   ```
3. Run your Next.js development server:
   ```bash
   npm run dev
   ```
   The API will now be live at:
   `http://localhost:3000/api/leaderboard`

---

## 2. Connecting the Game

In Godot, open `scripts/GameManager.gd` and verify or update line 79:
```gdscript
var leaderboard_api_url: String = "http://localhost:3000/api/leaderboard"
```
When deploying your Next.js app (e.g. on Vercel, Railway, Render):
```gdscript
var leaderboard_api_url: String = "https://your-site.vercel.app/api/leaderboard"
```

---

## 3. How Synchronization Works

1. **Offline Play**:
   When the player finishes the game (cleansing all 15 glitches), their completion time and player alias are saved into an encrypted file on the device (`user://records.enc`). The user cannot manually open or modify this file.

2. **Automatic Sync**:
   The game automatically attempts to POST any un-uploaded records to your Next.js API endpoint.
   - If online and the server responds with 200/201, the local record is marked as `uploaded = true`.
   - If offline, the run remains saved locally and will automatically retry syncing the next time the game is played or when the player opens the Leaderboard menu and presses "Refresh".

3. **In-Game Viewing**:
   Players can view both **Local Best** times and **Online World** records directly from the Main Menu or the Victory Screen.
