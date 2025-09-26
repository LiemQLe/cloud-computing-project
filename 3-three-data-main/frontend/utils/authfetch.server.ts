import config from "./config";

async function maybeIdToken(aud: string): Promise<string | undefined> {
    if (!aud) return undefined; // earlier sections: no token attached
    try {
        const ctrl = new AbortController();
        const to = setTimeout(() => ctrl.abort(), 150);
        const r = await fetch(`${config.METADATA}?audience=${encodeURIComponent(aud)}&format=full`, {
            headers: { 'Metadata-Flavor': 'Google' }, signal: ctrl.signal
        });
        clearTimeout(to);
        if (!r.ok) return undefined;
        return r.text();
    } catch { return undefined; }
}

export async function authedFetch(path: string, init?: RequestInit) {
    const headers = new Headers(init?.headers);
    const token = await maybeIdToken(config.AUD);
    if (token) headers.set('Authorization', `Bearer ${token}`);
    return fetch(`${config.API_ADDRESS}${path}`, { ...init, headers });
}