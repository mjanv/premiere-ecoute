import { action, KeyDownEvent, SingletonAction, WillAppearEvent } from "@elgato/streamdeck";
import { ICON_VOTE_UP } from "../icons";
import { getCurrentRating, setCurrentRating } from "./session-vote";

@action({ UUID: "com.maxime-janvier.premiere-ecoute.session-vote-up" })
export class SessionVoteUp extends SingletonAction {
	override async onWillAppear(ev: WillAppearEvent): Promise<void> {
		await ev.action.setTitle("");
		await ev.action.setImage(ICON_VOTE_UP);
	}

	override async onKeyDown(_ev: KeyDownEvent): Promise<void> {
		setCurrentRating(getCurrentRating() + 1);
	}
}
