defmodule PremiereEcoute.Wrapped.AppearanceTest do
  use ExUnit.Case, async: true

  alias PremiereEcoute.Wrapped.Appearance

  defp image(pixels, {h, w}), do: StbImage.new(for({r, g, b} <- pixels, into: <<>>, do: <<r, g, b>>), {h, w, 3})

  describe "struct" do
    test "has no colour by default and encodes to JSON" do
      assert %Appearance{cover_url: nil, colors: []} = %Appearance{}

      assert %Appearance{cover_url: "https://cover", colors: ["#fff"]} |> Jason.encode!() |> Jason.decode!() ==
               %{"cover_url" => "https://cover", "colors" => ["#fff"]}
    end
  end

  describe "palette/1" do
    test "returns the dominant colours, most present first" do
      pixels = List.duplicate({200, 20, 20}, 48) ++ List.duplicate({20, 20, 200}, 16)

      assert ["#c81414", "#1414c8"] = Appearance.palette(image(pixels, {8, 8}))
    end

    test "merges close colours" do
      pixels = List.duplicate({200, 20, 20}, 32) ++ List.duplicate({205, 22, 20}, 32)

      assert [_] = Appearance.palette(image(pixels, {8, 8}))
    end

    test "keeps three colours at most" do
      pixels = Enum.flat_map([{200, 20, 20}, {20, 200, 20}, {20, 20, 200}, {200, 200, 20}], &List.duplicate(&1, 16))

      assert length(Appearance.palette(image(pixels, {8, 8}))) == 3
    end

    test "reads an image of any size" do
      assert Appearance.palette(image(List.duplicate({200, 20, 20}, 64 * 64), {64, 64})) == ["#c81414"]
    end

    test "drops near-black colours when there is something brighter" do
      pixels = List.duplicate({5, 5, 5}, 48) ++ List.duplicate({200, 20, 20}, 16)

      assert Appearance.palette(image(pixels, {8, 8})) == ["#c81414"]
    end

    test "keeps a dark colour when the image has nothing else" do
      assert [_] = Appearance.palette(image(List.duplicate({5, 5, 5}, 64), {8, 8}))
    end
  end

  describe "extract/1" do
    test "reads the colours of a remote cover" do
      png = image(List.duplicate({10, 180, 90}, 16), {4, 4}) |> StbImage.to_binary(:png)

      Req.Test.stub(Appearance, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("image/png") |> Plug.Conn.send_resp(200, png)
      end)

      assert Appearance.extract("https://i.scdn.co/image/cover") == ["#0ab45a"]
    end

    test "returns no colour when the cover cannot be read" do
      Req.Test.stub(Appearance, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)

      assert Appearance.extract("https://i.scdn.co/image/missing") == []
      assert Appearance.extract(nil) == []
    end

    test "returns no colour on a server error, a broken connection or a body that is not an image" do
      Req.Test.stub(Appearance, fn conn -> Plug.Conn.send_resp(conn, 500, "") end)
      assert Appearance.extract("https://i.scdn.co/image/error") == []

      Req.Test.stub(Appearance, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)
      assert Appearance.extract("https://i.scdn.co/image/down") == []

      Req.Test.stub(Appearance, fn conn -> Plug.Conn.send_resp(conn, 200, "not an image") end)
      assert Appearance.extract("https://i.scdn.co/image/text") == []

      Req.Test.stub(Appearance, fn conn -> Req.Test.json(conn, %{error: "nope"}) end)
      assert Appearance.extract("https://i.scdn.co/image/json") == []
    end

    test "downloads nothing for something that is not a web address" do
      test = self()

      Req.Test.stub(Appearance, fn conn ->
        send(test, :fetched)
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert Appearance.extract("/images/cover.png") == []
      assert Appearance.extract("data:image/png;base64,AAAA") == []
      refute_received :fetched
    end
  end
end
