import { action, KeyDownEvent, SingletonAction, WillAppearEvent } from "@elgato/streamdeck";
import { api } from "../api-client";
import { ICON_PREVIOUS } from "../icons";

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-previous" })
export class SessionPrevious extends SingletonAction {
	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await ev.action.setImage(ICON_PREVIOUS);
		await ev.action.setTitle("");
	}

	override async onKeyDown(ev: KeyDownEvent): Promise<void> {
		const result = await api.previousTrack();

		if (result.ok) {
			await ev.action.showOk();
		} else {
			await ev.action.showAlert();
		}
	}
}
