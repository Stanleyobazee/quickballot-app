/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  // Browser code calls relative /api paths; the Next.js server forwards them
  // to the backend services. Targets are resolved when `next build` runs, not
  // at server start. The defaults match the Compose service names and the
  // planned Kubernetes Service names; overriding them requires a build argument.
  async rewrites() {
    const voteApi = process.env.VOTE_API_INTERNAL_URL || "http://vote-api:8080";
    const resultsApi =
      process.env.RESULTS_API_INTERNAL_URL || "http://results-api:8000";
    return [
      { source: "/api/polls/:path*", destination: `${voteApi}/api/polls/:path*` },
      {
        source: "/api/results/:path*",
        destination: `${resultsApi}/api/results/:path*`,
      },
    ];
  },
};

export default nextConfig;
