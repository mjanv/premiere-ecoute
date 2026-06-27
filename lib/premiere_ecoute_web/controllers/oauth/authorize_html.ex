defmodule PremiereEcouteWeb.Oauth.AuthorizeHTML do
  @moduledoc """
  OAuth consent and error templates for `PremiereEcouteWeb.Oauth.AuthorizeController`.
  """

  use PremiereEcouteWeb, :html

  embed_templates "authorize_html/*"
end
