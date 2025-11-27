defmodule PremiereEcoute.Telemetry.ReqPipeline do
  @moduledoc """
  Req telemetry pipeline.

  Attaches telemetry callbacks to Req HTTP requests for monitoring API calls with custom response handling.
  """

  alias Req.Request

  @doc """
  Attaches a telemetry callback to a Req HTTP request.

  Registers telemetry options and adds a response step that invokes the callback with provider name and request/response tuple. The callback executes after each response without modifying the request/response flow.
  """
  @spec attach(Request.t(), atom(), function()) :: Request.t()
  def attach(%Request{} = request, provider, callback) do
    request
    |> Request.register_options([:telemetry])
    |> Request.prepend_response_steps(
      telemetry: fn {request, response} ->
        callback.(provider, {request, response})
        {request, response}
      end
    )
  end
end
