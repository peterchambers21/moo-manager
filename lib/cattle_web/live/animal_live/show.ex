defmodule CattleWeb.AnimalLive.Show do
  use CattleWeb, :live_view

  alias Cattle.{Health, Herd}

  @kinds [{"Observation", :observation}, {"Treatment", :treatment}, {"Vaccination", :vaccination}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    animal = Herd.get_animal!(id)

    {:ok,
     socket
     |> assign(:kinds, @kinds)
     |> assign(:pens, Herd.list_pens())
     |> assign(:animal, animal)
     |> reset_forms()
     |> load()}
  end

  @impl true
  def handle_event("record_weight", %{"weigh_in" => params}, socket) do
    animal = socket.assigns.animal

    case Herd.record_weight(animal, params["weight_lb"], params["weighed_on"]) do
      {:ok, w} ->
        {:noreply,
         socket |> put_flash(:info, "Recorded #{lb(w.weight_lb)}.") |> reset_forms() |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, :weight_form, to_form(changeset))}
    end
  end

  def handle_event("record_event", %{"health_event" => params}, socket) do
    case Health.record_event(socket.assigns.animal, params) do
      {:ok, _event} ->
        {:noreply, socket |> put_flash(:info, "Health record saved.") |> reset_forms() |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, :event_form, to_form(changeset))}
    end
  end

  def handle_event("move", %{"pen_id" => pen_id}, socket) do
    pen = Enum.find(socket.assigns.pens, &(to_string(&1.id) == pen_id))

    case Herd.move_animal(socket.assigns.animal, pen) do
      {:ok, _} ->
        message = if pen, do: "Moved to #{pen.name}.", else: "Removed from pen."
        {:noreply, socket |> put_flash(:info, message) |> load()}

      {:error, :not_active} ->
        {:noreply, put_flash(socket, :error, "Only active animals can be moved.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Can't move: #{first_error(changeset)}.")}
    end
  end

  def handle_event("depart", %{"date" => date, "kind" => kind}, socket) do
    animal = socket.assigns.animal

    with {:ok, date} <- Date.from_iso8601(date),
         {:ok, _} <- depart(kind, animal, date) do
      verb = if kind == "ship", do: "shipped", else: "recorded as dead"
      {:noreply, socket |> put_flash(:info, "#{animal.tag} #{verb}.") |> load()}
    else
      {:error, :under_withdrawal} ->
        {:noreply,
         put_flash(socket, :error, "Can't ship: a drug withdrawal period covers that date.")}

      {:error, :not_active} ->
        {:noreply, put_flash(socket, :error, "This animal has already left.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         put_flash(socket, :error, "Can't record departure: #{first_error(changeset)}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Pick a valid date.")}
    end
  end

  defp depart("ship", animal, date), do: Herd.ship_animal(animal, date)
  defp depart("death", animal, date), do: Herd.record_death(animal, date)

  defp first_error(changeset) do
    {field, {message, _}} = hd(changeset.errors)
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end

  defp reset_forms(socket) do
    animal = socket.assigns.animal
    today = Date.utc_today()

    socket
    |> assign(:weight_form, to_form(Herd.change_weigh_in(animal, %{weighed_on: today})))
    |> assign(:event_form, to_form(Health.change_event(animal, %{occurred_on: today})))
  end

  defp load(socket) do
    animal = Herd.get_animal!(socket.assigns.animal.id)

    socket
    |> assign(:animal, animal)
    |> assign(:page_title, animal.tag)
    |> assign(:pen, Enum.find(socket.assigns.pens, &(&1.id == animal.pen_id)))
    |> assign(:weigh_ins, Herd.list_weigh_ins(animal))
    |> assign(:adg, Herd.average_daily_gain(animal))
    |> assign(:events, Health.list_events(animal))
    |> assign(:under_withdrawal?, Health.under_withdrawal?(animal))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@animal.tag}
        <span class={[status_badge(@animal.status), "ml-2 align-middle"]}>
          {label(@animal.status)}
        </span>
        <span :if={@under_withdrawal?} class="badge badge-warning ml-1 align-middle">
          Under withdrawal
        </span>
        <:subtitle>{@animal.breed} {@animal.sex && label(@animal.sex)}</:subtitle>
        <:actions>
          <.button navigate={~p"/animals/#{@animal}/edit"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <section class="grid gap-6 md:grid-cols-2">
        <.list>
          <:item title="Pen">
            <.link :if={@pen} navigate={~p"/pens/#{@pen}"} class="link">{@pen.name}</.link>
            <span :if={!@pen}>—</span>
          </:item>
          <:item title="Arrived">{date(@animal.arrival_date)}</:item>
          <:item title="Born">{date(@animal.birth_date)}</:item>
          <:item title="Source">{@animal.source || "—"}</:item>
          <:item :if={@animal.departure_date} title="Departed">{date(@animal.departure_date)}</:item>
          <:item title="Average daily gain">{adg(@adg)}</:item>
          <:item :if={@animal.notes} title="Notes">{@animal.notes}</:item>
        </.list>

        <div :if={@animal.status == :active} class="space-y-4">
          <form id="move-form" phx-submit="move" class="card bg-base-200 gap-2 p-4">
            <h3 class="font-semibold">Move to pen</h3>
            <div class="flex gap-2">
              <select name="pen_id" class="select select-sm flex-1">
                <option value="">No pen</option>
                <option :for={p <- @pens} value={p.id} selected={p.id == @animal.pen_id}>
                  {p.name}
                </option>
              </select>
              <button class="btn btn-sm">Move</button>
            </div>
          </form>

          <form id="depart-form" phx-submit="depart" class="card bg-base-200 gap-2 p-4">
            <h3 class="font-semibold">Departure</h3>
            <input type="date" name="date" value={Date.utc_today()} class="input input-sm" />
            <div class="flex gap-2">
              <button name="kind" value="ship" class="btn btn-sm btn-primary flex-1">Ship</button>
              <button
                name="kind"
                value="death"
                class="btn btn-sm btn-ghost flex-1"
                data-confirm="Record #{@animal.tag} as dead?"
              >
                Record death
              </button>
            </div>
          </form>
        </div>
      </section>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2">
          <h2 class="mb-2 font-semibold">Weigh-ins</h2>
          <p :if={@weigh_ins == []} class="text-base-content/70">No weigh-ins yet.</p>
          <.table :if={@weigh_ins != []} id="weigh-ins" rows={@weigh_ins}>
            <:col :let={w} label="Date">{date(w.weighed_on)}</:col>
            <:col :let={w} label="Weight">{lb(w.weight_lb)}</:col>
          </.table>
        </div>
        <div class="card bg-base-200 p-4">
          <h3 class="font-semibold">Record weight</h3>
          <.form for={@weight_form} id="weight-form" phx-submit="record_weight">
            <.input field={@weight_form[:weighed_on]} type="date" label="Date" />
            <.input field={@weight_form[:weight_lb]} type="number" step="0.1" label="Weight (lb)" />
            <.button class="btn btn-primary mt-2 w-full">Record</.button>
          </.form>
        </div>
      </section>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2">
          <h2 class="mb-2 font-semibold">Health records</h2>
          <p :if={@events == []} class="text-base-content/70">No health records yet.</p>
          <.table :if={@events != []} id="health-events" rows={@events}>
            <:col :let={e} label="Date">{date(e.occurred_on)}</:col>
            <:col :let={e} label="Kind">{label(e.kind)}</:col>
            <:col :let={e} label="Description">{e.description}</:col>
            <:col :let={e} label="Product">{e.product} {e.dose}</:col>
            <:col :let={e} label="Withdrawal until">{date(e.withdrawal_until)}</:col>
          </.table>
        </div>
        <div class="card bg-base-200 p-4">
          <h3 class="font-semibold">Add health record</h3>
          <.form for={@event_form} id="event-form" phx-submit="record_event">
            <.input field={@event_form[:occurred_on]} type="date" label="Date" />
            <.input field={@event_form[:kind]} type="select" label="Kind" options={@kinds} />
            <.input field={@event_form[:description]} label="Description" />
            <.input field={@event_form[:product]} label="Product" />
            <.input field={@event_form[:dose]} label="Dose" />
            <.input field={@event_form[:withdrawal_until]} type="date" label="Withdrawal until" />
            <.button class="btn btn-primary mt-2 w-full">Save</.button>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
