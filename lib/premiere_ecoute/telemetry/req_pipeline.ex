defmodule PremiereEcoute.Telemetry.ReqPipeline do
  @moduledoc false

  alias Req.Request

  def attach(%Request{} = request, callback) do
    request
    |> Request.register_options([:telemetry])
    |> Request.prepend_response_steps(
      telemetry: fn {request, response} ->
        callback.({request, response})
        {request, response}
      end
    )
  end
end
