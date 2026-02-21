defmodule PremiereEcoute.Apis.RateLimit.RateLimiter do
  @moduledoc """
  Rate limiting for API requests.

  Provides rate limiting functionality using Hammer with an ETS backend to prevent exceeding external API rate limits.
  """

  use Hammer, backend: :ets
end
