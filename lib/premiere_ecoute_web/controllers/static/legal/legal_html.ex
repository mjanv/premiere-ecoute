defmodule PremiereEcouteWeb.Static.Legal.LegalHTML do
  @moduledoc """
  Legal documents view templates.

  Renders legal documents including privacy policy, cookie policy, terms of service, and contact information.
  """

  use PremiereEcouteWeb, :html

  embed_templates "/html/*"
end
