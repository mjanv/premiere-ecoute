import streamDeck from "@elgato/streamdeck";

import { SessionVote } from "./actions/session-vote";
import { SessionVoteUp } from "./actions/session-vote-up";
import { SessionVoteDown } from "./actions/session-vote-down";

streamDeck.logger.setLevel("trace");

streamDeck.actions.registerAction(new SessionVote());
streamDeck.actions.registerAction(new SessionVoteUp());
streamDeck.actions.registerAction(new SessionVoteDown());

streamDeck.connect();
