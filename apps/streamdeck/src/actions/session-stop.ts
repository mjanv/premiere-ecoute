import { action, KeyDownEvent, SingletonAction, WillAppearEvent } from "@elgato/streamdeck";
import { api } from "../api-client";
import { ICON_STOP } from "../icons";

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-stop" })
export class SessionStop extends SingletonAction {
	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await ev.action.setImage(ICON_STOP);
		await ev.action.setTitle("");
	}

	override async onKeyDown(ev: KeyDownEvent): Promise<void> {
		const result = await api.stopSession();

		if (result.ok) {
			await ev.action.showOk();
		} else {
			await ev.action.showAlert();
		}
	}
}
