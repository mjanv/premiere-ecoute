defmodule PremiereEcouteCore.Utils do
  @moduledoc """
  Core utility functions.

  Provides string sanitization utilities for normalizing track names.
  """

  def sanitize_track(value) when is_binary(value) do
    value
    # Remove text enclosed in (), [] or located after -
    |> String.replace(~r/ \(.+\).*| \[.+\].*| -.+/, "")
    |> String.downcase()
    # Unicode Normalization Form Decomposed
    |> :unicode.characters_to_nfd_binary()
    # Remove diacritical marks
    |> String.replace(~r/\p{Mn}/u, "")
    # Remove interrogation & exclamation marks
    |> String.replace(~r/[!?]+$/, "")
    |> String.replace(~r/^[!?]+/, "")
    |> String.replace(~r/ [!?]+/, " ")
    |> String.replace(~r/[!?]+ /, " ")
    |> String.replace(~r/[¿¡*,.'':_\/-]/, "")
    # Remove special characters
    |> String.replace("œ", "oe")
    |> String.replace("$", "s")
    |> String.replace("ø", "o")
    |> String.trim()
  end
end
