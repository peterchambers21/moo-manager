defmodule CattleWeb.PenLive.Show do
  use CattleWeb, :live_view

  alias Cattle.{Feed, Herd}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    pen = Herd.get_pen!(id)
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:pen, pen)
     |> assign(:page_title, pen.name)
     |> assign(:from, Date.add(today, -29))
     |> assign(:to, today)
     |> assign(:feeding_form, feeding_form(pen))
     |> load()}
  end

  @impl true
  def handle_event("range", %{"from" => from, "to" => to}, socket) do
    with {:ok, from} <- Date.from_iso8601(from),
         {:ok, to} <- Date.from_iso8601(to),
         true <- Date.compare(from, to) != :gt do
      {:noreply, socket |> assign(from: from, to: to) |> load()}
    else
      _ -> {:noreply, put_flash(socket, :error, "Pick a start date on or before the end date.")}
    end
  end

  def handle_event("record_feeding", %{"feeding" => params}, socket) do
    case Feed.record_feeding(socket.assigns.pen, params) do
      {:ok, feeding} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recorded #{lb(feeding.amount_lb)} of #{feeding.feed_type}.")
         |> assign(:feeding_form, feeding_form(socket.assigns.pen))
         |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, :feeding_form, to_form(changeset))}
    end
  end

  defp feeding_form(pen), do: to_form(Feed.change_feeding(pen, %{fed_on: Date.utc_today()}))

  defp load(%{assigns: %{pen: pen, from: from, to: to}} = socket) do
    socket
    |> assign(:head_count, Herd.head_count(pen))
    |> assign(:animals, Herd.list_animals(pen: pen))
    |> assign(:avg_weight, Herd.pen_average_weight(pen))
    |> assign(:adg, Herd.pen_average_daily_gain(pen))
    |> assign(:feedings, Feed.list_feedings(pen, from, to))
    |> assign(:total_fed, Feed.total_fed(pen, from, to))
    |> assign(:per_head_day, Feed.feed_per_head_per_day(pen, from, to))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@pen.name}
        <:subtitle>{@pen.notes}</:subtitle>
        <:actions>
          <.button navigate={~p"/pens/#{@pen}/edit"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <div class="stats stats-vertical sm:stats-horizontal w-full shadow">
        <div class="stat">
          <div class="stat-title">Head</div>
          <div class="stat-value">{head(@head_count, @pen.capacity)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Average weight</div>
          <div class="stat-value text-2xl">{lb(@avg_weight)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Average daily gain</div>
          <div class="stat-value text-2xl">{adg(@adg)}</div>
        </div>
      </div>

      <section>
        <h2 class="mb-2 font-semibold">Animals</h2>
        <p :if={@animals == []} class="text-base-content/70">No active animals in this pen.</p>
        <.table
          :if={@animals != []}
          id="pen-animals"
          rows={@animals}
          row_click={fn a -> JS.navigate(~p"/animals/#{a}") end}
        >
          <:col :let={a} label="Tag">{a.tag}</:col>
          <:col :let={a} label="Breed">{a.breed}</:col>
          <:col :let={a} label="Sex">{label(a.sex)}</:col>
          <:col :let={a} label="Arrived">{date(a.arrival_date)}</:col>
        </.table>
      </section>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2">
          <h2 class="mb-2 font-semibold">Feed</h2>
          <form id="feed-range" phx-change="range" class="mb-3 flex flex-wrap items-end gap-2">
            <label class="text-sm">
              From <input type="date" name="from" value={@from} class="input input-sm" />
            </label>
            <label class="text-sm">
              To <input type="date" name="to" value={@to} class="input input-sm" />
            </label>
          </form>
          <p class="mb-2 text-sm">
            <strong>{lb(@total_fed)}</strong>
            total<span :if={@per_head_day}>, {lb(@per_head_day)} per head per day</span>.
          </p>
          <p :if={@feedings == []} class="text-base-content/70">No feedings in this range.</p>
          <.table :if={@feedings != []} id="feedings" rows={@feedings}>
            <:col :let={f} label="Date">{date(f.fed_on)}</:col>
            <:col :let={f} label="Feed">{f.feed_type}</:col>
            <:col :let={f} label="Amount">{lb(f.amount_lb)}</:col>
            <:col :let={f} label="Notes">{f.notes}</:col>
          </.table>
        </div>

        <div class="card bg-base-200 p-4">
          <h3 class="font-semibold">Record a feeding</h3>
          <.form for={@feeding_form} id="feeding-form" phx-submit="record_feeding">
            <.input field={@feeding_form[:fed_on]} type="date" label="Date" />
            <.input field={@feeding_form[:feed_type]} label="Feed type" placeholder="e.g. hay" />
            <.input field={@feeding_form[:amount_lb]} type="number" step="0.1" label="Amount (lb)" />
            <.input field={@feeding_form[:notes]} label="Notes" />
            <.button variant="primary" class="btn btn-primary mt-2 w-full">Record</.button>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
