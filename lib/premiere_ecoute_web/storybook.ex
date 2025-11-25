defmodule PremiereEcouteWeb.Storybook do
  @moduledoc """
  Phoenix Storybook configuration.

  Configures the Phoenix Storybook for component documentation and visual testing with custom styling and dark mode support.
  """

  use PhoenixStorybook,
    otp_app: :premiere_ecoute,
    content_path: Path.expand("../../storybook", __DIR__),
    css_path: "/assets/css/app.css",
    js_path: "/assets/js/storybook.js",
    sandbox_class: "premiere-ecoute-sandbox",
    title: "Premiere Ecoute - Storybook",
    color_mode: true
end
