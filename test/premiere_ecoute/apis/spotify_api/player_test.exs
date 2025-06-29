defmodule PremiereEcoute.Apis.SpotifyApi.PlayerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.SpotifyApi.Player

  @moduletag :spotify

  @token "AQD1O7o4MimZtntMijtuuzO2PRmd8ePFcEHw13K3OglLR8kWpASN3Wt2pLXGvfz5f0dwIFa2DTs--G1GNUDAVr5cMFaGX0QQLnNF9ycUg5havJbs_cG-v23Cl0blFylPL4tV-H6rbA-NuRZIZihSs3A5Xn3XzAW5pY7l8_ymHj0RmrXct36IrWOnZamzjucX5J_dr04AQDpNUmuM7xp2UYxbu3UQP4z_2_70y5jKefNgGbr1G4nwg9Za18Ahx5u60xHV2nEXsoofzO39OvicZCWstWnkRXjN8FWo8eNjC-hNGiZNGpLD0z4eBVhlfkrxLFcQGMsRQKbMITC4zfAjUFshuKCsbw"

  describe "get_playback_state/1" do
    test "?" do
      Player.get_playback_state(@token)
    end
  end
end
