import streamDeck from "@elgato/streamdeck";

export type GlobalSettings = {
	serverUrl?: string;
	apiToken?: string;
};

export type Session = {
	id: string;
	status: string;
	source: string;
	cover_url: string | null;
	viewer_score: number | string | null;
};

export type ApiResult<T> =
	| { ok: true; data: T }
	| { ok: false; status: number; message: string };

let cachedSettings: GlobalSettings = {};

streamDeck.settings.onDidReceiveGlobalSettings((ev) => {
	cachedSettings = ev.settings as GlobalSettings;
});


streamDeck.settings.getGlobalSettings();

async function request<T>(method: string, path: string): Promise<ApiResult<T>> {
	const baseUrl = cachedSettings.serverUrl ?? "http://localhost:4000";
	const token = cachedSettings.apiToken ?? "";

	let response: Response;
	try {
		response = await fetch(`${baseUrl}${path}`, {
			method,
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${token}`,
			},
		});
	} catch (err) {
		return { ok: false, status: 0, message: String(err) };
	}

	if (!response.ok) {
		let message = response.statusText;
		try {
			const body = await response.json() as { error?: string };
			if (body.error) message = body.error;
		} catch {
			// ignore
		}
		return { ok: false, status: response.status, message };
	}

	const data = await response.json() as T;
	return { ok: true, data };
}

async function requestWithBody<T>(method: string, path: string, body: unknown): Promise<ApiResult<T>> {
	const baseUrl = cachedSettings.serverUrl ?? "http://localhost:4000";
	const token = cachedSettings.apiToken ?? "";

	let response: Response;
	try {
		response = await fetch(`${baseUrl}${path}`, {
			method,
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${token}`,
			},
			body: JSON.stringify(body),
		});
	} catch (err) {
		return { ok: false, status: 0, message: String(err) };
	}

	if (!response.ok) {
		let message = response.statusText;
		try {
			const b = await response.json() as { error?: string };
			if (b.error) message = b.error;
		} catch { /* ignore */ }
		return { ok: false, status: response.status, message };
	}

	const data = await response.json() as T;
	return { ok: true, data };
}

export const api = {
	getSession: () => request<Session>("GET", "/api/session"),
	startSession: () => request<{ ok: boolean }>("POST", "/api/session/start"),
	stopSession: () => request<{ ok: boolean }>("POST", "/api/session/stop"),
	nextTrack: () => request<{ ok: boolean }>("POST", "/api/session/next"),
	previousTrack: () => request<{ ok: boolean }>("POST", "/api/session/previous"),
	voteTrack: (rating: number) => requestWithBody<{ ok: boolean; rating: number }>("POST", "/api/session/vote", { rating }),
};
