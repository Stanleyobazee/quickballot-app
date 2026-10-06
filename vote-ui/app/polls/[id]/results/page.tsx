"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";

interface OptionResult {
  id: string;
  label: string;
  vote_count: number;
  percentage: number;
}

interface PollResults {
  poll_id: string;
  question: string;
  status: string;
  total_votes: number;
  options: OptionResult[];
}

export default function ResultsPage() {
  const { id } = useParams<{ id: string }>();
  const [results, setResults] = useState<PollResults | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchResults = useCallback(async () => {
    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_RESULTS_API_URL}/api/results/${id}`,
        { cache: "no-store" }
      );
      if (!res.ok) throw new Error("Failed to fetch");
      const data = await res.json();
      setResults(data);
      setError(null);
    } catch {
      setError("Could not load results. Retrying…");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetchResults();
    const interval = setInterval(fetchResults, 5000);
    return () => clearInterval(interval);
  }, [fetchResults]);

  const hasVoted = typeof window !== "undefined"
    ? !!localStorage.getItem(`voted_${id}`)
    : false;

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div
          className="w-8 h-8 rounded-full border-2 animate-spin"
          style={{ borderColor: "var(--indigo)", borderTopColor: "transparent" }}
        />
      </div>
    );
  }

  if (error && !results) {
    return (
      <div
        className="rounded-xl px-8 py-10 text-center"
        style={{ backgroundColor: "var(--navy-800)", border: "1px solid var(--navy-700)" }}
      >
        <p className="text-base font-medium" style={{ color: "#f87171" }}>{error}</p>
      </div>
    );
  }

  if (!results) return null;

  const colors = ["#4f46e5", "#7c3aed", "#0ea5e9", "#10b981", "#f59e0b", "#ef4444"];

  return (
    <div className="max-w-xl">
      <Link
        href="/"
        className="inline-flex items-center gap-1 text-sm mb-8 no-underline"
        style={{ color: "var(--text-muted)" }}
      >
        ← All polls
      </Link>

      <div className="mb-8">
        <h1
          className="text-2xl font-bold tracking-tight mb-2 leading-snug"
          style={{ color: "var(--surface)" }}
        >
          {results.question}
        </h1>
        <div className="flex items-center gap-3">
          <span className="text-sm" style={{ color: "var(--text-muted)" }}>
            {results.total_votes} {results.total_votes === 1 ? "vote" : "votes"} total
          </span>
          <span
            className="text-xs font-medium px-2 py-0.5 rounded-full"
            style={{
              backgroundColor: results.status === "closed"
                ? "rgba(239,68,68,0.15)"
                : "rgba(16,185,129,0.15)",
              color: results.status === "closed" ? "#f87171" : "#34d399",
            }}
          >
            {results.status === "closed" ? "Closed" : "Live"}
          </span>
        </div>
      </div>

      <div className="space-y-5 mb-10">
        {results.options.map((opt, i) => (
          <div key={opt.id}>
            <div className="flex justify-between items-baseline mb-1.5">
              <span className="text-sm font-medium" style={{ color: "var(--surface)" }}>
                {opt.label}
              </span>
              <span className="text-sm tabular-nums" style={{ color: "var(--text-muted)" }}>
                {opt.vote_count} · {opt.percentage}%
              </span>
            </div>
            <div
              className="h-2.5 rounded-full overflow-hidden"
              style={{ backgroundColor: "var(--navy-700)" }}
            >
              <div
                className="h-full rounded-full transition-all duration-700"
                style={{
                  width: `${opt.percentage}%`,
                  backgroundColor: colors[i % colors.length],
                }}
              />
            </div>
          </div>
        ))}
      </div>

      {results.status === "active" && !hasVoted && (
        <Link
          href={`/polls/${id}`}
          className="inline-block px-6 py-3 rounded-xl font-semibold text-sm text-white no-underline"
          style={{ backgroundColor: "var(--indigo)" }}
        >
          Cast your vote
        </Link>
      )}

      <p className="text-xs mt-6" style={{ color: "var(--navy-700)" }}>
        Results refresh automatically every 5 seconds
      </p>
    </div>
  );
}