/**
 * Resolves the backend API base URL for server-side route handlers.
 *
 * Route handlers across `app/api/*` each inlined
 * `process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000/api"`. That default
 * is convenient locally and wrong everywhere else: a deployment that forgets to
 * set the variable does not fail, it silently points production traffic at a
 * loopback address that is not listening, and the UI shows an empty page rather
 * than an error.
 *
 * This keeps the zero-config local default but makes the production path refuse
 * to guess.
 */

/** Local default. Matches `PORT=4000` in `Backend/.env.example`. */
const DEVELOPMENT_FALLBACK = "http://localhost:4000/api";

export class MissingApiBaseError extends Error {
  constructor() {
    super(
      "NEXT_PUBLIC_API_URL is not set. It is required in production builds — " +
        "there is no safe default, so requests would otherwise be sent to " +
        "localhost. See Frontend/.env.example.",
    );
    this.name = "MissingApiBaseError";
  }
}

/**
 * @returns the API base with any trailing slash removed.
 * @throws {MissingApiBaseError} in production when the variable is unset.
 */
export function resolveApiBase(): string {
  const configured = process.env.NEXT_PUBLIC_API_URL?.trim();

  if (configured) {
    return configured.replace(/\/+$/, "");
  }

  if (process.env.NODE_ENV === "production") {
    throw new MissingApiBaseError();
  }

  return DEVELOPMENT_FALLBACK;
}
