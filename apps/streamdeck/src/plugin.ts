import streamDeck from "@elgato/streamdeck";

import { SessionStatus } from "./actions/session-status";
import { SessionStart } from "./actions/session-start";
import { SessionStop } from "./actions/session-stop";
import { SessionNext } from "./actions/session-next";
import { SessionPrevious } from "./actions/session-previous";
import { SessionVote } from "./actions/session-vote";
import { SessionVoteUp } from "./actions/session-vote-up";
import { SessionVoteDown } from "./actions/session-vote-down";

streamDeck.logger.setLevel("trace");

streamDeck.actions.registerAction(new SessionStatus());
streamDeck.actions.registerAction(new SessionStart());
streamDeck.actions.registerAction(new SessionStop());
streamDeck.actions.registerAction(new SessionNext());
streamDeck.actions.registerAction(new SessionPrevious());
streamDeck.actions.registerAction(new SessionVote());
streamDeck.actions.registerAction(new SessionVoteUp());
streamDeck.actions.registerAction(new SessionVoteDown());

streamDeck.connect();
