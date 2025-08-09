defmodule PremiereEcouteWeb.Components.Modal do
  @moduledoc """
  Modal dialog components with consistent styling and behavior.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PremiereEcouteWeb.CoreComponents

  @doc """
  Renders a modal dialog with backdrop and consistent styling.

  ## Examples

      <.modal id="my-modal" show={@show_modal} on_cancel={JS.push("hide_modal")}>
        <:header>
          Modal Title
        </:header>
        <p>Modal content goes here</p>
        <:footer>
          <button phx-click="save">Save</button>
          <button phx-click="cancel">Cancel</button>
        </:footer>
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :size, :string, default: "md", values: ~w(sm md lg xl full), doc: "Modal size"
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header, doc: "Modal header content"
  slot :inner_block, required: true, doc: "Modal body content"
  slot :footer, doc: "Modal footer content"

  def modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      phx-click={@on_cancel}
      {@rest}
    >
      <div
        class={[
          "bg-surface-elevated rounded-lg shadow-xl mx-4 flex flex-col",
          modal_size_classes(@size),
          @class
        ]}
        phx-click="modal_content_click"
      >
        <!-- Header -->
        <div :if={@header != []} class="flex items-center justify-between p-6 border-b border-surface">
          <div class="flex items-center space-x-3">
            {render_slot(@header)}
          </div>
          <button type="button" phx-click={@on_cancel} class="text-surface-muted hover:text-surface-primary">
            <CoreComponents.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto p-6">
          {render_slot(@inner_block)}
        </div>

        <!-- Footer -->
        <div :if={@footer != []} class="flex justify-end p-6 border-t border-surface">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  # AIDEV-NOTE: Modal size helper function for responsive sizing
  defp modal_size_classes(size) do
    case size do
      "sm" -> "max-w-sm w-full max-h-[80vh]"
      "md" -> "max-w-md w-full max-h-[80vh]"
      "lg" -> "max-w-2xl w-full max-h-[80vh]"
      "xl" -> "max-w-4xl w-full max-h-[80vh]"
      "full" -> "max-w-full w-full h-full m-0 rounded-none"
    end
  end
end