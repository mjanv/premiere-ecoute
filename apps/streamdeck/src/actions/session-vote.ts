import streamDeck, { action, KeyAction, KeyDownEvent, SingletonAction, WillAppearEvent, WillDisappearEvent } from "@elgato/streamdeck";
import { api } from "../api-client";
import { iconVote } from "../icons";

// AIDEV-NOTE: vote state is shared across all three vote actions via module-level variables;
// onRatingChange callback allows up/down actions to trigger a re-render of the vote button.
let currentRating = 5;
let onRatingChange: (() => void) | undefined;

export function getCurrentRating(): number {
	return currentRating;
}

export function setCurrentRating(rating: number): void {
	currentRating = Math.max(0, Math.min(10, rating));
	onRatingChange?.();
}

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-vote" })
export class SessionVote extends SingletonAction {
	private keyAction: KeyAction | undefined;

	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		this.keyAction = ev.action as KeyAction;
		onRatingChange = () => this.render();
		await this.render();
	}

	override onWillDisappear(_ev: WillDisappearEvent): void {
		this.keyAction = undefined;
		onRatingChange = undefined;
	}

	override async onKeyDown(ev: KeyDownEvent): Promise<void> {
		const result = await api.voteTrack(currentRating);

		if (result.ok) {
			await ev.action.showOk();
		} else {
			streamDeck.logger.error(`voteTrack failed: ${JSON.stringify(result)}`);
			await ev.action.showAlert();
		}
	}

	private async render(): Promise<void> {
		if (!this.keyAction) return;
		await this.keyAction.setTitle("");
		await this.keyAction.setImage(iconVote(currentRating));
	}
}
