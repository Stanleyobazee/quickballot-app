"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";

interface Option {
  id: string;
  label: string;
  display_order: number;
}

interface Poll {
  id: string;
  question: string;
  status: string;
  options: Option[];
}

function getOrCreateVoterToken(): string {
  let token = localStorage.getItem("quickballot_voter_token");
  if (!token) {
    token = crypto.randomUUID();
    localStorage.setItem("quickballot_voter_token", token);
  }
  return token;
}

export default function PollPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [poll, setPoll] = useState<Poll | null>(null);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [, setAlreadyVoted] = useState(false);

  useEffect(() => {
    const voted = localStorage.getItem(`voted_${id}`);
    if (voted) {
      router.replace(`/polls/${id}/results`);
      return;
    }

    fetch(`${process.env.NEXT_PUBLIC_VOTE_API_URL}/api/polls/${id}`)
      .then((r) => r.json())
      .then((data) => {
        if (data.status === "closed") {
          router.replace(`/polls/${id}/results`);
        } else {
          setPoll(data);
        }
      })
      .catch(() => setError("Could not load this poll. Please try again."))
      .finally(() => setLoading(false));
  }, [id, router]);

  async function handleVote() {
    if (!selected) return;
    setSubmitting(true);
    setError(null);

    const voterToken = getOrCreateVoterToken();

    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_VOTE_API_URL}/api/polls/${id}/votes`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ optionId: selected, voterToken }),
        }
      );

      if (res.status === 409) {
        setAlreadyVoted(true);
        localStorage.setItem(`voted_${id}`, "1");
        router.push(`/polls/${id}/results`);
        return;
      }

      if (!res.ok) {
        const data = await res.json();
        setError(data.error || "Something went wrong. Please try again.");
        return;
      }

      localStorage.setItem(`voted_${id}`, "1");
      router.push(`/polls/${id}/results`);
    } catch {
      setError("Network error. Check your connection and try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div
          className="w-8 h-8 rounded-full border-2 border-t-transparent animate-spin"
          style={{ borderColor: "var(--indigo)", borderTopColor: "transparent" }}
        />
      </div>
    );
  }

  if (error && !poll) {
    return (
      <div
        className="rounded-xl px-8 py-10 text-center"
        style={{ backgroundColor: "var(--navy-800)", border: "1px solid var(--navy-700)" }}
      >
        <p className="text-base font-medium mb-4" style={{ color: "#f87171" }}>{error}</p>
        <Link href="/" className="text-sm" style={{ color: "var(--indigo-light)" }}>
          Back to polls
        </Link>
      </div>
    );
  }

  if (!poll) return null;

  return (
    <div className="max-w-xl">
      <Link
        href="/"
        className="inline-flex items-center gap-1 text-sm mb-8 no-underline"
        style={{ color: "var(--text-muted)" }}
      >
        ← All polls
      </Link>

      <h1
        className="text-2xl font-bold tracking-tight mb-8 leading-snug"
        style={{ color: "var(--surface)" }}
      >
        {poll.question}
      </h1>

      <div className="space-y-3 mb-8">
        {poll.options
          .sort((a, b) => a.display_order - b.display_order)
          .map((opt) => (
            <button
              key={opt.id}
              onClick={() => setSelected(opt.id)}
              className="w-full text-left px-5 py-4 rounded-xl transition-all duration-150 font-medium text-base"
              style={{
                backgroundColor:
                  selected === opt.id
                    ? "rgba(79,70,229,0.2)"
                    : "var(--navy-800)",
                border:
                  selected === opt.id
                    ? "1px solid var(--indigo)"
                    : "1px solid var(--navy-700)",
                color:
                  selected === opt.id
                    ? "var(--surface)"
                    : "var(--text-muted)",
              }}
            >
              {opt.label}
            </button>
          ))}
      </div>

      {error && (
        <p className="text-sm mb-4" style={{ color: "#f87171" }}>
          {error}
        </p>
      )}

      <button
        onClick={handleVote}
        disabled={!selected || submitting}
        className="w-full py-3 rounded-xl font-semibold text-base text-white transition-opacity duration-150"
        style={{
          backgroundColor: "var(--indigo)",
          opacity: !selected || submitting ? 0.5 : 1,
          cursor: !selected || submitting ? "not-allowed" : "pointer",
        }}
      >
        {submitting ? "Submitting…" : "Cast vote"}
      </button>
    </div>
  );
}