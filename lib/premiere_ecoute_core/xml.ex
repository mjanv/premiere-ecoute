defmodule PremiereEcouteCore.Xml do
  @moduledoc """
  Thin wrapper around `:xmerl` for parsing an XML string and querying it with XPath.

  A document (or any element returned by `xpath/2`) can be passed back into the same
  functions, so traversal composes naturally:

      doc = Xml.parse(xml_string)
      [track | _] = Xml.xpath(doc, "/xmeml/sequence/media/video/track")
      Xml.xpath(track, "clipitem") |> length()
      Xml.text(Xml.xpath(doc, "/xmeml/sequence/uuid"))
      Xml.attr(element, :id)
  """

  @type document :: tuple()
  @type element :: tuple()
  @type node_t :: document() | element()

  @doc """
  Parses an XML string into a document tree.
  """
  @spec parse(String.t()) :: document()
  def parse(xml_string) when is_binary(xml_string) do
    xml_string
    |> String.to_charlist()
    |> :xmerl_scan.string(quiet: true)
    |> elem(0)
  end

  @doc """
  Runs an XPath expression against a document or element. Always returns a list.
  """
  @spec xpath(node_t(), String.t()) :: [element()]
  def xpath(doc, path) when is_binary(path) do
    :xmerl_xpath.string(String.to_charlist(path), doc)
  end

  @doc """
  Returns the text content of an element. When given a list, returns the list of texts.
  """
  @spec text(element() | [element()] | tuple()) :: String.t() | [String.t()]
  def text(elements) when is_list(elements), do: Enum.map(elements, &text/1)

  def text({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    children
    |> Enum.filter(&match?({:xmlText, _, _, _, _, _}, &1))
    |> Enum.map_join(fn {:xmlText, _, _, _, value, _} -> to_string(value) end)
  end

  def text({:xmlText, _, _, _, value, _}), do: to_string(value)

  @doc """
  Returns the value of an attribute on an element, or `nil` if it's missing.
  """
  @spec attr(element(), atom()) :: String.t() | nil
  def attr({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}, attr_name) when is_atom(attr_name) do
    case Enum.find(attrs, fn {:xmlAttribute, name, _, _, _, _, _, _, _, _} -> name == attr_name end) do
      {:xmlAttribute, _, _, _, _, _, _, _, value, _} -> to_string(value)
      nil -> nil
    end
  end
end
