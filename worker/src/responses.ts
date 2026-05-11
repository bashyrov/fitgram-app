export function jsonResponse(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
        },
    });
}

export function problemResponse(status: number, message: string, extras: Record<string, unknown> = {}): Response {
    return jsonResponse({ error: message, ...extras }, status);
}
