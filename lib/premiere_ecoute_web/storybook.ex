defmodule PremiereEcouteWeb.Storybook do
  @moduledoc false

  use PhoenixStorybook,
    otp_app: :premiere_ecoute,
    content_path: Path.expand("../../storybook", __DIR__),
    css_path: "/assets/css/app.css",
    js_path: "/assets/js/storybook.js",
    sandbox_class: "premiere-ecoute-sandbox",
    title: "Premiere Ecoute - Storybook"
end
