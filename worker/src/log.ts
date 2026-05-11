type Level = "debug" | "info" | "warn" | "error";

const ORDER: Record<Level, number> = { debug: 0, info: 1, warn: 2, error: 3 };

export function makeLogger(level: string) {
    const threshold = ORDER[(level as Level) in ORDER ? (level as Level) : "info"];
    const emit = (lvl: Level, msg: string, ctx?: Record<string, unknown>) => {
        if (ORDER[lvl] < threshold) return;
        const line = ctx ? `${msg} ${JSON.stringify(ctx)}` : msg;
        const banner = `[${lvl}]`;
        // Cloudflare Logs ingest stdout. Using console.* is the documented path.
        // eslint-disable-next-line no-console
        console.log(`${banner} ${line}`);
    };
    return {
        debug: (msg: string, ctx?: Record<string, unknown>) => emit("debug", msg, ctx),
        info: (msg: string, ctx?: Record<string, unknown>) => emit("info", msg, ctx),
        warn: (msg: string, ctx?: Record<string, unknown>) => emit("warn", msg, ctx),
        error: (msg: string, ctx?: Record<string, unknown>) => emit("error", msg, ctx),
    };
}

export type Logger = ReturnType<typeof makeLogger>;
