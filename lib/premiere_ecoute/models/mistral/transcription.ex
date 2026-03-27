defmodule PremiereEcoute.Models.Mistral.Transcription do
  @moduledoc false

  @url "https://api.mistral.ai/v1/audio/transcriptions"

  @doc """
    %Req.Response{
      status: 200,
      headers: %{
        "access-control-allow-origin" => ["*"],
        "alt-svc" => ["h3=\":443\"; ma=86400"],
        "cf-cache-status" => ["DYNAMIC"],
        "cf-ray" => ["9e31b0ad18d66f94-CDG"],
        "connection" => ["keep-alive"],
        "content-type" => ["application/json"],
        "date" => ["Fri, 27 Mar 2026 22:04:20 GMT"],
        "mistral-correlation-id" => ["019d3153-a85d-779f-b8f4-0b1065f6a906"],
        "server" => ["cloudflare"],
        "server-timing" => ["cfCacheStatus;desc=\"DYNAMIC\"",
        "cfEdge;dur=32,cfOrigin;dur=1039"],
        "set-cookie" => ["__cf_bm=S2FOQMVS9.vfX626Jz8AWxsneoVBnzgQuwhWUAu4a3I-1774649059.3735769-1.0.1.1-92ZVw14oiqYG.3qlpQbyf.NqeyyMgXs2T_VCJzYmXc5cymRhGQ.ImuoJqwy72LDTcajs4JjOu5HamwOIE8W3cWRFh_gKNHv9vtDkNjqAGbbCo1eUHQAaI_Mg.emAuTuO; HttpOnly; Secure; Path=/; Domain=mistral.ai; Expires=Fri, 27 Mar 2026 22:34:20 GMT",
        "_cfuvid=ydXYX7gMrdbr.mq_5uJJiwnOzH.0wIOB0Nn1FTzCP1k-1774649059.3735769-1.0.1.1-qLCnf5Jq0BXXXMRD0dRkd9rGM8bw9TO6d0w.sdvTxBw; HttpOnly; SameSite=None; Secure; Path=/; Domain=mistral.ai"],
        "strict-transport-security" => ["max-age=15552000; includeSubDomains; preload"],
        "transfer-encoding" => ["chunked"],
        "x-content-type-options" => ["nosniff"],
        "x-envoy-upstream-service-time" => ["966"],
        "x-kong-proxy-latency" => ["42"],
        "x-kong-request-id" => ["019d3153-a85d-779f-b8f4-0b1065f6a906"],
        "x-kong-upstream-latency" => ["967"],
        "x-ratelimit-audio-seconds-query-cost" => ["5"],
        "x-ratelimit-limit-audio-seconds-minute" => ["3600"],
        "x-ratelimit-limit-req-minute" => ["60"],
        "x-ratelimit-remaining-audio-seconds-minute" => ["3595"],
        "x-ratelimit-remaining-req-minute" => ["59"]
      },
      body: %{
        "finish_reason" => nil,
        "language" => nil,
        "model" => "voxtral-mini-2507",
        "segments" => [],
        "text" => "Bonjour, je suis une piste audio de test.",
        "usage" => %{
          "completion_tokens" => 12,
          "prompt_audio_seconds" => 5,
          "prompt_tokens" => 7,
          "prompt_tokens_details" => %{"cached_tokens" => 0},
          "total_tokens" => 394
        }
      },
      trailers: %{},
      private: %{}
    }
  """
  def transcribe(path) do
    Req.post!(
      @url,
      headers: [
        {"x-api-key", Application.get_env(:premiere_ecoute, :mistral)[:api_key]}
      ],
      form_multipart: [
        file: {File.read!(path), filename: Path.basename(path), content_type: "audio/mpeg"},
        model: "voxtral-mini-2507",
        language: "fr"
      ]
    )
  end
end
