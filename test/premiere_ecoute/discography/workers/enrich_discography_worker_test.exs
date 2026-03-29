defmodule PremiereEcoute.Discography.Workers.EnrichDiscographyWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker

  describe "run/1" do
    test "returns :error when artist is not found" do
      assert {:error, :not_found} = EnrichDiscographyWorker.run(nil)
    end
  end
end
