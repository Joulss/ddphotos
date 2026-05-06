// Cloudflare Pages Worker — handles URL routing for DD Photos static deployments.
// Copied into the export root as _worker.js by `ddphotos export --cloudflare` (or export.sh --cloudflare).
// Handles photo permalinks (/albums/slug/42 → /albums/slug.html), photo permalink trailing slash
// redirects (308), and extensionless root-level paths (/ → index.html, /privacy → privacy.html).
// See docs/DEPLOYMENT-SERVERS.md#cloudflare-pages-worker for details.
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;

        // Trailing slash on photo permalinks: /albums/slug/42/ → 308 → /albums/slug/42
        const trailingSlash = path.match(/^(\/albums\/[^\/]+\/\d+)\/$/);
        if (trailingSlash) {
            return Response.redirect(new URL(trailingSlash[1], url.origin).toString(), 308);
        }

        // Photo permalink: /albums/slug/42 → serve /albums/slug.html
        // Equivalent to the CloudFront Function handler for S3+CloudFront deployments.
        const match = path.match(/^\/albums\/([^\/]+)\/\d+$/);
        if (match) {
            const newUrl = new URL(`/albums/${match[1]}.html`, url.origin);
            return env.ASSETS.fetch(newUrl.toString());
        }

        // Root → index.html; other extensionless single-segment paths → path.html
        // (e.g. /privacy → /privacy.html). Unknown paths produce a 404 from ASSETS.
        if (!path.includes('.') && path.indexOf('/', 1) === -1) {
            const html = path === '/' ? '/index.html' : path + '.html';
            return env.ASSETS.fetch(new URL(html, url.origin).toString());
        }

        return env.ASSETS.fetch(request);
    }
};
