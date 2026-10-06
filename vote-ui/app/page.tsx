import Link from "next/link";

interface Poll {
  id: string;
  question: string;
  status: string;
  created_at: string;
  options: { id: string; label: string; display_order: number }[];
}

async function getPolls(): Promise<Poll[]> {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_VOTE_API_URL}/api/polls`,
      { cache: "no-store" }
    );
    if (!res.ok) return [];
    return res.json();
  } catch {
    return [];
  }
}

export default async function HomePage() {
  const polls = await getPolls();

  return (
    <div>
      <div className="mb-10">
        <h1
          className="text-3xl font-bold tracking-tight mb-2"
          style={{ color: "var(--surface)" }}
        >
          Active polls
        </h1>
        <p className="text-base" style={{ color: "var(--text-muted)" }}>
          Choose a poll below to cast your vote. Results update in real time.
        </p>
      </div>

      {polls.length === 0 ? (
        <div
          className="rounded-xl px-8 py-12 text-center"
          style={{ backgroundColor: "var(--navy-800)", border: "1px solid var(--navy-700)" }}
        >
          <p className="text-lg font-medium mb-1" style={{ color: "var(--surface)" }}>
            No active polls right now
          </p>
          <p className="text-sm" style={{ color: "var(--text-muted)" }}>
            Check back soon — new polls are added regularly.
          </p>
        </div>
      ) : (
        <ul className="space-y-4">
          {polls.map((poll) => (
            <li key={poll.id}>
              <Link href={`/polls/${poll.id}`} className="block no-underline group">
                <div
                  className="rounded-xl px-6 py-5 transition-colors duration-150"
                  style={{
                    backgroundColor: "var(--navy-800)",
                    border: "1px solid var(--navy-700)",
                  }}
                  onMouseEnter={(e) =>
                    (e.currentTarget.style.borderColor = "var(--indigo)")
                  }
                  onMouseLeave={(e) =>
                    (e.currentTarget.style.borderColor = "var(--navy-700)")
                  }
                >
                  <p
                    className="text-base font-semibold mb-2 leading-snug"
                    style={{ color: "var(--surface)" }}
                  >
                    {poll.question}
                  </p>
                  <div className="flex items-center gap-4">
                    <span className="text-sm" style={{ color: "var(--text-muted)" }}>
                      {poll.options.length} options
                    </span>
                    <span
                      className="text-xs font-medium px-2 py-0.5 rounded-full"
                      style={{
                        backgroundColor: "rgba(79,70,229,0.15)",
                        color: "var(--indigo-light)",
                      }}
                    >
                      Vote now
                    </span>
                  </div>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}