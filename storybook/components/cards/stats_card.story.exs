defmodule Storybook.Components.Cards.StatsCard do
  @moduledoc false

  use PhoenixStorybook.Story, :component

  def function, do: &PremiereEcouteWeb.Components.StatsCard.stats_card/1
  def render_source, do: :function

  def variations do
    [
      %VariationGroup{
        id: :colors,
        variations: [
          %Variation{
            id: :blue,
            attributes: %{
              icon: "hero-users",
              value: "1,234",
              label: "Total Users",
              color: "blue"
            }
          },
          %Variation{
            id: :green,
            attributes: %{
              icon: "hero-check-circle",
              value: "98.5%",
              label: "Success Rate",
              color: "green"
            }
          },
          %Variation{
            id: :yellow,
            attributes: %{
              icon: "hero-exclamation-triangle",
              value: "23",
              label: "Warnings",
              color: "yellow"
            }
          },
          %Variation{
            id: :purple,
            attributes: %{
              icon: "hero-musical-note",
              value: "456",
              label: "Sessions",
              color: "purple"
            }
          },
          %Variation{
            id: :orange,
            attributes: %{
              icon: "hero-clock",
              value: "2.3h",
              label: "Avg. Duration",
              color: "orange"
            }
          },
          %Variation{
            id: :red,
            attributes: %{
              icon: "hero-x-circle",
              value: "12",
              label: "Errors",
              color: "red"
            }
          },
          %Variation{
            id: :gray,
            attributes: %{
              icon: "hero-cube",
              value: "89",
              label: "Inactive",
              color: "gray"
            }
          }
        ]
      },
      %VariationGroup{
        id: :different_icons,
        variations: [
          %Variation{
            id: :chart_bar,
            attributes: %{
              icon: "hero-chart-bar",
              value: "$12.5K",
              label: "Revenue",
              color: "green"
            }
          },
          %Variation{
            id: :heart,
            attributes: %{
              icon: "hero-heart",
              value: "8.9K",
              label: "Likes",
              color: "red"
            }
          },
          %Variation{
            id: :eye,
            attributes: %{
              icon: "hero-eye",
              value: "24.7K",
              label: "Views",
              color: "blue"
            }
          }
        ]
      },
      %VariationGroup{
        id: :value_formats,
        variations: [
          %Variation{
            id: :number,
            attributes: %{
              icon: "hero-users",
              value: "1,234",
              label: "Users",
              color: "blue"
            }
          },
          %Variation{
            id: :percentage,
            attributes: %{
              icon: "hero-chart-pie",
              value: "87%",
              label: "Completion",
              color: "green"
            }
          },
          %Variation{
            id: :currency,
            attributes: %{
              icon: "hero-banknotes",
              value: "$45.2K",
              label: "Revenue",
              color: "green"
            }
          },
          %Variation{
            id: :time,
            attributes: %{
              icon: "hero-clock",
              value: "2h 15m",
              label: "Duration",
              color: "orange"
            }
          }
        ]
      },
      %VariationGroup{
        id: :interactive,
        template: """
        <div class="space-y-4" psb-code-hidden>
          <.psb-variation/>
        </div>
        """,
        variations: [
          %Variation{
            id: :clickable,
            attributes: %{
              icon: "hero-chart-bar",
              value: "1,234",
              label: "View Analytics",
              color: "blue",
              navigate: "/analytics"
            }
          }
        ]
      }
    ]
  end
end
