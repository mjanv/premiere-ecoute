defmodule PremiereEcouteCore.XmlTest do
  use ExUnit.Case, async: true

  alias PremiereEcouteCore.Xml

  @sample """
  <?xml version="1.0" encoding="UTF-8"?>
  <root>
    <item id="1" kind="alpha">first</item>
    <item id="2" kind="beta">second</item>
    <group>
      <item id="3">nested</item>
    </group>
  </root>
  """

  describe "parse/1" do
    test "returns the root element" do
      doc = Xml.parse(@sample)
      assert {:xmlElement, :root, _, _, _, _, _, _, _, _, _, _} = doc
    end
  end

  describe "xpath/2" do
    test "returns a list of matching elements" do
      doc = Xml.parse(@sample)
      items = Xml.xpath(doc, "/root/item")
      assert length(items) == 2
    end

    test "returns an empty list when no match" do
      doc = Xml.parse(@sample)
      assert Xml.xpath(doc, "/root/missing") == []
    end

    test "queries can be applied to nested elements" do
      doc = Xml.parse(@sample)
      [group] = Xml.xpath(doc, "/root/group")
      [item] = Xml.xpath(group, "item")
      assert Xml.text(item) == "nested"
    end
  end

  describe "text/1" do
    test "extracts text from a single element" do
      doc = Xml.parse(@sample)
      [item] = Xml.xpath(doc, "/root/item[@id='1']")
      assert Xml.text(item) == "first"
    end

    test "maps over a list of elements" do
      doc = Xml.parse(@sample)
      texts = Xml.xpath(doc, "/root/item") |> Xml.text()
      assert texts == ["first", "second"]
    end

    test "extracts text from a text node directly" do
      doc = Xml.parse(@sample)
      [item] = Xml.xpath(doc, "/root/item[@id='2']")
      {:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = item
      [text_node] = Enum.filter(children, &match?({:xmlText, _, _, _, _, _}, &1))
      assert Xml.text(text_node) == "second"
    end
  end

  describe "attr/2" do
    test "returns the attribute value as a string" do
      doc = Xml.parse(@sample)
      [item] = Xml.xpath(doc, "/root/item[@id='1']")
      assert Xml.attr(item, :id) == "1"
      assert Xml.attr(item, :kind) == "alpha"
    end

    test "returns nil for a missing attribute" do
      doc = Xml.parse(@sample)
      [item] = Xml.xpath(doc, "/root/group/item")
      assert Xml.attr(item, :kind) == nil
    end
  end
end
