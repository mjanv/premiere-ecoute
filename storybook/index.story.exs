defmodule Storybook.Index do
  @moduledoc false

  use PhoenixStorybook.Story, :page

  def doc, do: "Your very first steps into using Phoenix Storybook"

  def render(assigns) do
    ~H"""
    <div class="psb-welcome-page">
      <p>
        We generated your storybook with an example of a page and a component.
        Explore the generated <code class="psb:inline">*.story.exs</code>
        files in your <code class="inline">/storybook</code>
        directory. When you're ready to add your own, just drop your new story & index files into the same directory and refresh your storybook.
      </p>

      <p>
        Here are a few docs you might be interested in:
      </p>

      <.description_list items={[
        {"Create a new Story", doc_link("Story")},
        {"Display components using Variations", doc_link("Stories.Variation")},
        {"Group components using VariationGroups", doc_link("Stories.VariationGroup")},
        {"Organize the sidebar with Index files", doc_link("Index")}
      ]} />

      <p>
        This should be enough to get you started, but you can use the tabs in the upper-right corner of this page to <strong>check out advanced usage guides</strong>.
      </p>
    </div>
    """
  end

  defp description_list(assigns) do
    ~H"""
    <div class="psb:w-full psb:md:px-8">
      <div class="psb:md:border-t psb:border-gray-200 psb:px-4 psb:py-5 psb:sm:p-0 psb:md:my-6 psb:w-full">
        <dl class="psb:sm:divide-y psb:sm:divide-gray-200">
          <%= for {dt, link} <- @items do %>
            <div class="psb:py-4 psb:sm:grid psb:sm:grid-cols-3 psb:sm:gap-4 psb:sm:py-5 psb:sm:px-6 psb:max-w-full">
              <dt class="psb:text-base psb:font-medium psb:text-indigo-700">
                {dt}
              </dt>
              <dd class="psb:mt-1 psb:text-base psb:text-slate-400 psb:sm:col-span-2 psb:sm:mt-0 psb:group psb:cursor-pointer psb:max-w-full">
                <a class="psb:group-hover:text-indigo-700 psb:max-w-full psb:inline-block psb:truncate" href={link} target="_blank">
                  {link}
                </a>
              </dd>
            </div>
          <% end %>
        </dl>
      </div>
    </div>
    """
  end

  defp doc_link(page), do: "https://hexdocs.pm/phoenix_storybook/PhoenixStorybook.#{page}.html"
end
