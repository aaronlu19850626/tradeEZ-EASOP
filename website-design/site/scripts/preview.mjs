// Serve the production static export locally, without a framework server.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { resolve, relative, extname, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../out/", import.meta.url));
const port = Number(process.env.PORT || 5173);
const mime = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".json": "application/json", ".txt": "text/plain; charset=utf-8", ".png": "image/png", ".svg": "image/svg+xml", ".woff2": "font/woff2", ".ico": "image/x-icon" };
await stat(resolve(root, "index.html"));
const server = createServer(async (req, res) => {
  if (!["GET", "HEAD"].includes(req.method || "")) { res.writeHead(405, { Allow: "GET, HEAD" }); res.end(); return; }
  try {
    const pathname = decodeURIComponent(new URL(req.url || "/", "http://localhost").pathname);
    let path = resolve(root, `.${pathname}`);
    const rel = relative(root, path);
    if (rel === ".." || rel.startsWith(`..${sep}`) || rel.includes(":")) { res.writeHead(403); res.end(); return; }
    const info = await stat(path);
    if (info.isDirectory()) path = resolve(path, "index.html");
    const body = await readFile(path);
    res.writeHead(200, { "Content-Type": mime[extname(path)] || "application/octet-stream", "Cache-Control": "no-cache", "X-Content-Type-Options": "nosniff" });
    res.end(req.method === "HEAD" ? undefined : body);
  } catch {
    res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
    const page = await readFile(resolve(root, "404.html")).catch(() => "Not found");
    res.end(req.method === "HEAD" ? undefined : page);
  }
});
server.listen(port, "127.0.0.1", () => console.log(`TradeEZ static preview: http://127.0.0.1:${port}/`));
