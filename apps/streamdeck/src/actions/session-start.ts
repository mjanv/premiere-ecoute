import streamDeck, { action, KeyDownEvent, SingletonAction, WillAppearEvent } from "@elgato/streamdeck";
import { api } from "../api-client";
import { ICON_START } from "../icons";

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-start" })
export class SessionStart extends SingletonAction {
	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await ev.action.setImage(ICON_START);
		await ev.action.setTitle("");
	}

	override async onKeyDown(ev: KeyDownEvent): Promise<void> {
		const result = await api.startSession();

		if (result.ok) {
			await ev.action.showOk();
		} else {
			streamDeck.logger.error(`startSession failed: status=${result.status} message=${result.message}`);
			await ev.action.showAlert();
		}
	}
}
