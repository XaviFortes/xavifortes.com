/**
 * Defang indicators for display.
 *
 *   https://evil.example.com/x  ->  hxxps://evil[.]example[.]com/x
 *   1.2.3.4                     ->  1[.]2[.]3[.]4
 *
 * Hashes, mutexes, paths, registry keys and user-agents pass through untouched.
 * They aren't resolvable, and mangling them makes them useless to a reader.
 */

const PASS_THROUGH = new Set([
  "sha256",
  "sha1",
  "md5",
  "mutex",
  "path",
  "registry",
  "useragent",
]);

export function defang(value: string, type?: string): string {
  if (type && PASS_THROUGH.has(type)) return value;

  return value
    .replace(/^h(tt|xx)ps:/i, "hxxps:")
    .replace(/^h(tt|xx)p:/i, "hxxp:")
    .replace(/^ftp:/i, "fxp:")
    .replace(/@/g, "[at]")
    .replace(/\./g, "[.]");
}

export function iocTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    domain: "domains",
    url: "urls",
    ip: "ip addresses",
    "ip:port": "ip:port",
    sha256: "sha-256",
    sha1: "sha-1",
    md5: "md5",
    mutex: "mutexes",
    path: "file paths",
    registry: "registry keys",
    useragent: "user agents",
    email: "email addresses",
  };
  return labels[type] ?? type;
}

/** Escape a string for inclusion in XML/RSS output. */
export function escapeXml(unsafe: string): string {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}
