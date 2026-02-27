import { action, KeyDownEvent, SingletonAction, WillAppearEvent } from "@elgato/streamdeck";
import { ICON_VOTE_DOWN } from "../icons";
import { getCurrentRating, setCurrentRating } from "./session-vote";

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-vote-down" })
export class SessionVoteDown extends SingletonAction {
	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await ev.action.setTitle("");
		await ev.action.setImage(ICON_VOTE_DOWN);
	}

	override async onKeyDown(_ev: KeyDownEvent): Promise<void> {
		setCurrentRating(getCurrentRating() - 1);
	}
}
