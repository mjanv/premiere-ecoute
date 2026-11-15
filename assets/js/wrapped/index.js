import { WrappedPlayer } from "./renders/classic";
import { WrappedPlayerPixel } from "./renders/pixel";

// The renders of a Wrapped: one LiveView hook per render, each in its own folder under ./renders.
// A hook name here must match the `hook` of a render in PremiereEcouteWeb.Wrapped.Renders.
export const WrappedRenders = {
  WrappedPlayer,
  WrappedPlayerPixel,
};
