import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "QuickBallot",
  description: "Fast, simple polling for teams and communities",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen" style={{ backgroundColor: "var(--navy)" }}>
        <header style={{ backgroundColor: "var(--navy-800)", borderBottom: "1px solid var(--navy-700)" }}>
          <div className="max-w-3xl mx-auto px-6 py-4 flex items-center justify-between">
            <a href="/" className="flex items-center gap-2 no-underline">
              <div
                className="w-7 h-7 rounded-md flex items-center justify-center text-white text-sm font-bold"
                style={{ backgroundColor: "var(--indigo)" }}
              >
                Q
              </div>
              <span className="text-white font-semibold text-lg tracking-tight">
                QuickBallot
              </span>
            </a>
            <span className="text-xs font-medium px-2 py-1 rounded-full" style={{ backgroundColor: "var(--navy-700)", color: "var(--indigo-light)" }}>
              Live voting
            </span>
          </div>
        </header>
        <main className="max-w-3xl mx-auto px-6 py-10">
          {children}
        </main>
        <footer className="max-w-3xl mx-auto px-6 py-8 mt-10" style={{ borderTop: "1px solid var(--navy-700)" }}>
          <p className="text-sm" style={{ color: "var(--text-muted)" }}>
            QuickBallot — anonymous, real-time polls
          </p>
        </footer>
      </body>
    </html>
  );
}