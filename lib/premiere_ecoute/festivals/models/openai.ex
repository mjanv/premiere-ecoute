defmodule PremiereEcoute.Festivals.Models.OpenAi do
  @moduledoc false

  @behaviour PremiereEcoute.Festivals.Models.Model

  alias PremiereEcoute.Festivals.Festival

  @prompt """
  You are given a festival poster. Perform a two-step task:

  ### Step 1: OCR Extraction
  - Extract **all visible text** from the image, including small or faint fonts.  
  - Do **not** summarize or skip content.  
  - Keep the raw text as close to what is printed on the poster as possible.

  ### Step 2: Structured Output
  From the extracted text, identify and organize the following:

  1. **Festival Name**  
  2. **Dates and Location(s)**  
  3. **Full Lineup of Performers**  
    - Include **all artists**, both headliners and smaller acts.  
    - Do not omit names because of font size or position.  
    - Output as a clean list without duplicates.
    
  ### Important Instructions
  - Treat **all text as important**, even if it looks small or secondary.
  - Do **not** return only the largest names — the goal is the *full lineup*.
  - If uncertain about a word (due to small text), still include it as best-effort.
  """

  def extract_festival(base64_image) do
    Instructor.chat_completion(
      model: "gpt-4o",
      stream: true,
      response_model: {:partial, Festival},
      messages: [
        %{
          role: "user",
          content: [
            %{
              type: "text",
              text: @prompt
            },
            %{
              type: "image_url",
              image_url: %{url: base64_image, detail: "auto"}
            }
          ]
        }
      ]
    )
  end
end
