defmodule PremiereEcoute.Events.BuyMeACoffee.Donation do
  @moduledoc """
  Represents a donation from a BuyMeACoffee supporter.

  This struct is returned by the API when fetching supporter information.
  """

  @type t :: %__MODULE__{
          supporter_name: String.t(),
          support_note: String.t(),
          support_coffees: integer(),
          transaction_id: String.t(),
          supporter_email: String.t() | nil,
          support_visibility: integer(),
          support_created_on: String.t(),
          support_updated_on: String.t(),
          transfer_id: String.t() | nil,
          supporter_id: integer() | nil,
          support_note_id: integer(),
          payment_id: integer(),
          support_id: integer()
        }

  defstruct [
    :supporter_name,
    :support_note,
    :support_coffees,
    :transaction_id,
    :supporter_email,
    :support_visibility,
    :support_created_on,
    :support_updated_on,
    :transfer_id,
    :supporter_id,
    :support_note_id,
    :payment_id,
    :support_id
  ]

  @doc """
  Parses API supporter data into a Donation struct.
  """
  @spec parse(map()) :: t()
  def parse(data) when is_map(data) do
    %__MODULE__{
      supporter_name: data["supporter_name"],
      support_note: data["support_note"],
      support_coffees: data["support_coffees"],
      transaction_id: data["transaction_id"],
      supporter_email: data["supporter_email"],
      support_visibility: data["support_visibility"],
      support_created_on: data["support_created_on"],
      support_updated_on: data["support_updated_on"],
      transfer_id: data["transfer_id"],
      supporter_id: data["supporter_id"],
      support_note_id: data["support_note_id"],
      payment_id: data["payment_id"],
      support_id: data["support_id"]
    }
  end
end
