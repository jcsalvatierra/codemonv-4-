import { NextRequest, NextResponse } from "next/server";

export interface LeaderboardRecord {
  player_name: string;
  completion_time: number;
  formatted_time: string;
  date: string;
  bugs_defeated: number;
}

// In-memory fallback store for instant local testing without an external DB.
// In production, replace this with your database client (e.g. Prisma, Supabase, Drizzle, MongoDB).
let inMemoryLeaderboard: LeaderboardRecord[] = [
  {
    player_name: "CodeMaster_Dev",
    completion_time: 245.5,
    formatted_time: "04:05.50",
    date: "2026-09-24 10:15",
    bugs_defeated: 15,
  },
  {
    player_name: "SyntaxStriker",
    completion_time: 312.8,
    formatted_time: "05:12.80",
    date: "2026-09-24 11:30",
    bugs_defeated: 15,
  },
];

/**
 * GET /api/leaderboard
 * Returns the top records sorted by completion_time ascending (fastest first).
 */
export async function GET(_req: NextRequest) {
  try {
    // Sort ascending by completion_time
    const sorted = [...inMemoryLeaderboard].sort(
      (a, b) => a.completion_time - b.completion_time
    );

    return NextResponse.json(
      {
        success: true,
        records: sorted,
      },
      { status: 200 }
    );
  } catch (error) {
    console.error("Leaderboard GET Error:", error);
    return NextResponse.json(
      { success: false, error: "Internal server error" },
      { status: 500 }
    );
  }
}

/**
 * POST /api/leaderboard
 * Receives an array of run completion records or a single record.
 * Validates, records, and returns the updated leaderboard count.
 */
export async function POST(req: NextRequest) {
  try {
    // Validate optional API secret key if configured in .env
    const serverApiKey = process.env.CODEMON_API_KEY;
    if (serverApiKey) {
      const clientApiKey = req.headers.get("x-api-key");
      if (clientApiKey !== serverApiKey) {
        return NextResponse.json(
          { success: false, error: "Unauthorized: Invalid or missing x-api-key" },
          { status: 401 }
        );
      }
    }

    const body = await req.json();
    const incoming: LeaderboardRecord[] = Array.isArray(body.records)
      ? body.records
      : Array.isArray(body)
      ? body
      : [body];

    const validNewRecords: LeaderboardRecord[] = [];

    for (const record of incoming) {
      if (
        !record ||
        typeof record.completion_time !== "number" ||
        record.completion_time <= 0
      ) {
        continue;
      }

      const cleanName =
        typeof record.player_name === "string" && record.player_name.trim().length > 0
          ? record.player_name.trim().slice(0, 32)
          : "Anonymous_Coder";

      const formattedTime =
        typeof record.formatted_time === "string"
          ? record.formatted_time
          : `${record.completion_time.toFixed(2)}s`;

      const dateStr =
        typeof record.date === "string"
          ? record.date
          : new Date().toISOString().replace("T", " ").slice(0, 16);

      const bugs =
        typeof record.bugs_defeated === "number" ? record.bugs_defeated : 15;

      const sanitized: LeaderboardRecord = {
        player_name: cleanName,
        completion_time: record.completion_time,
        formatted_time: formattedTime,
        date: dateStr,
        bugs_defeated: bugs,
      };

      validNewRecords.push(sanitized);
      inMemoryLeaderboard.push(sanitized);
    }

    // Keep sorted
    inMemoryLeaderboard.sort((a, b) => a.completion_time - b.completion_time);

    return NextResponse.json(
      {
        success: true,
        saved_count: validNewRecords.length,
        total_records: inMemoryLeaderboard.length,
      },
      { status: 201 }
    );
  } catch (error) {
    console.error("Leaderboard POST Error:", error);
    return NextResponse.json(
      { success: false, error: "Failed to process leaderboard submission" },
      { status: 400 }
    );
  }
}
