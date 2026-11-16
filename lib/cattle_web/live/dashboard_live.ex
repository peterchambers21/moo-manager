defmodule CattleWeb.DashboardLive do
  use CattleWeb, :live_view

  alias Cattle.{Health, Herd}

  @impl true
  def mount(_params, _session, socket) do
    pens =
      for pen <- Herd.list_pens() do
        %{
          pen: pen,
          head_count: Herd.head_count(pen),
          avg_weight: Herd.pen_average_weight(pen),
          adg: Herd.pen_average_daily_gain(pen)
        }
      end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:head_count, length(Herd.list_animals()))
     |> assign(:avg_weight, Herd.herd_average_weight())
     |> assign(:adg, Herd.herd_average_daily_gain())
     |> assign(:pens, pens)
     |> assign(:withdrawals, Health.animals_under_withdrawal())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Dashboard
        <:subtitle>Active animals on the feedlot today.</:subtitle>
        <:actions>
          <.button navigate={~p"/animals/new"} variant="primary">
            <.icon name="hero-plus" /> Register animal
          </.button>
        </:actions>
      </.header>

      <div class="stats stats-vertical sm:stats-horizontal w-full shadow">
        <div class="stat">
          <div class="stat-title">Head on feed</div>
          <div class="stat-value">{@head_count}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Average weight</div>
          <div class="stat-value text-2xl">{lb(@avg_weight)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Average daily gain</div>
          <div class="stat-value text-2xl">{adg(@adg)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Under withdrawal</div>
          <div class={["stat-value", @withdrawals != [] && "text-warning"]}>
            {length(@withdrawals)}
          </div>
        </div>
      </div>

      <section>
        <h2 class="mb-2 font-semibold">Pens</h2>
        <p :if={@pens == []} class="text-base-content/70">
          No pens yet. <.link navigate={~p"/pens/new"} class="link">Add one</.link>.
        </p>
        <.table
          :if={@pens != []}
          id="pen-summary"
          rows={@pens}
          row_click={fn row -> JS.navigate(~p"/pens/#{row.pen}") end}
        >
          <:col :let={row} label="Pen">{row.pen.name}</:col>
          <:col :let={row} label="Head">{head(row.head_count, row.pen.capacity)}</:col>
          <:col :let={row} label="Avg weight">{lb(row.avg_weight)}</:col>
          <:col :let={row} label="ADG">{adg(row.adg)}</:col>
        </.table>
      </section>

      <section :if={@withdrawals != []}>
        <h2 class="mb-2 font-semibold">Drug withdrawal</h2>
        <p class="mb-2 text-sm text-base-content/70">
          These animals can't ship until the day after their withdrawal ends.
        </p>
        <.table
          id="withdrawals"
          rows={@withdrawals}
          row_click={fn {animal, _} -> JS.navigate(~p"/animals/#{animal}") end}
        >
          <:col :let={{animal, _}} label="Tag">{animal.tag}</:col>
          <:col :let={{_, until}} label="Withdrawal ends">{date(until)}</:col>
          <:col :let={{_, until}} label="Can ship from">{date(Date.add(until, 1))}</:col>
        </.table>
      </section>
    </Layouts.app>
    """
  end
end
