import { action, KeyAction, SingletonAction, WillAppearEvent, WillDisappearEvent } from "@elgato/streamdeck";
import { api } from "../api-client";
import { ICON_STATUS } from "../icons";

const POLL_INTERVAL_MS = 5000;

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-status" })
export class SessionStatus extends SingletonAction {
	private timer: ReturnType<typeof setInterval> | undefined;
	private lastSessionId: string | undefined;
	private lastViewerScore: number | string | null | undefined = undefined;
	private coverDataUrl: string | null = null;

	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		const keyAction = ev.action as KeyAction;
		await keyAction.setImage(ICON_STATUS);
		await keyAction.setTitle("");
		await this.refresh(keyAction);
		this.timer = setInterval(() => this.refresh(keyAction), POLL_INTERVAL_MS);
	}

	override onWillDisappear(_ev: WillDisappearEvent): void {
		clearInterval(this.timer);
		this.timer = undefined;
		this.lastSessionId = undefined;
		this.lastViewerScore = undefined;
		this.coverDataUrl = null;
	}

	private async refresh(keyAction: KeyAction): Promise<void> {
		const result = await api.getSession();

		if (!result.ok) {
			if (this.lastSessionId !== undefined) {
				this.lastSessionId = undefined;
				this.lastViewerScore = undefined;
				this.coverDataUrl = null;
				await keyAction.setImage(ICON_STATUS);
				await keyAction.setTitle("");
			}
			return;
		}

		const { id, status, cover_url, viewer_score } = result.data;

		// Fetch cover only when session changes
		if (id !== this.lastSessionId) {
			this.lastSessionId = id;
			this.lastViewerScore = undefined;
			this.coverDataUrl = null;

			if (status === "active" && cover_url) {
				this.coverDataUrl = await fetchImageAsDataUrl(cover_url);
			}
		}

		// Re-render only when score changes
		if (viewer_score !== this.lastViewerScore) {
			this.lastViewerScore = viewer_score;

			if (this.coverDataUrl) {
				await keyAction.setImage(compositeImage(this.coverDataUrl, viewer_score));
			} else {
				await keyAction.setImage(ICON_STATUS);
			}
			await keyAction.setTitle("");
		}
	}
}

function compositeImage(coverDataUrl: string, score: number | string | null): string {
	const scoreText = score !== null ? String(score) : "";
	const markup = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 144 144">
  <image href="${coverDataUrl}" x="0" y="0" width="144" height="144" preserveAspectRatio="xMidYMid slice"/>
  ${scoreText !== "" ? `
  <rect x="0" y="88" width="144" height="56" fill="rgba(0,0,0,0.55)"/>
  <text x="72" y="134" text-anchor="middle" font-size="44" font-family="sans-serif" font-weight="bold" fill="white">${scoreText}</text>
  ` : ""}
</svg>`;
	return `data:image/svg+xml,${encodeURIComponent(markup)}`;
}

async function fetchImageAsDataUrl(url: string): Promise<string | null> {
	try {
		const response = await fetch(url);
		if (!response.ok) return null;
		const buffer = await response.arrayBuffer();
		const contentType = response.headers.get("content-type") ?? "image/jpeg";
		const base64 = Buffer.from(buffer).toString("base64");
		return `data:${contentType};base64,${base64}`;
	} catch {
		return null;
	}
}
