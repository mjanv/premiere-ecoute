defmodule PremiereEcouteCore.GoofyWords do
  @moduledoc """
  Generates random short, goofy words for use as submission deletion tokens.

  These words are meant to be memorable but not easily guessable.
  """

  @goofy_words [
    "banana",
    "wiggly",
    "bouncy",
    "fluffy",
    "snazzy",
    "zesty",
    "quirky",
    "wobbly",
    "fizzy",
    "giggly",
    "dizzy",
    "funky",
    "zippy",
    "bubbly",
    "goofy",
    "wonky",
    "silly",
    "jazzy",
    "peppy",
    "snappy",
    "zappy",
    "wooly",
    "bumpy",
    "lumpy",
    "jumpy",
    "spunky",
    "chunky",
    "clunky",
    "breezy",
    "cheesy",
    "wheezy",
    "sneezy",
    "sleepy",
    "creepy",
    "weepy",
    "loopy",
    "droopy",
    "snoopy",
    "poopy",
    "gloppy",
    "floppy",
    "sloppy",
    "choppy",
    "poppy",
    "hoppy",
    "soppy",
    "nippy",
    "dippy",
    "hippy",
    "tippy",
    "skippy",
    "snippy",
    "whippy",
    "grippy",
    "trippy",
    "flippy",
    "slippy",
    "drippy",
    "sticky",
    "tricky",
    "picky",
    "icky",
    "wacky",
    "tacky",
    "snacky",
    "cracky",
    "whacky",
    "quacky",
    "smacky",
    "hacky",
    "lacky",
    "packy",
    "racky",
    "salty",
    "malty",
    "faulty",
    "vaulte",
    "mighty",
    "flighty",
    "nighty",
    "righty",
    "tighty",
    "brainy",
    "grainy",
    "rainy",
    "zany",
    "shiny",
    "tiny",
    "spiny",
    "whiny",
    "briny",
    "piney"
  ]

  @doc """
  Generates a random goofy word from the predefined list.

  ## Examples

      iex> PremiereEcoute.Utils.GoofyWords.generate()
      "banana"

  """
  @spec generate() :: String.t()
  def generate do
    Enum.random(@goofy_words)
  end

  @doc """
  Generates a random goofy word with a random number suffix (1-999).

  This provides more uniqueness while keeping the token memorable.

  ## Examples

      iex> PremiereEcoute.Utils.GoofyWords.generate_with_number()
      "banana42"

  """
  @spec generate_with_number() :: String.t()
  def generate_with_number do
    word = generate()
    number = Enum.random(1..999)
    "#{word}#{number}"
  end
end
