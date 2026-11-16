defmodule CattleWeb.AnimalLive.Index do
  use CattleWeb, :live_view

  alias Cattle.Herd

  @statuses ~w(active shipped dead all)

  @impl true
  def mount(_params, _session, socket) do
    pens = Herd.list_pens()

    {:ok,
     socket
     |> assign(:page_title, "Animals")
     |> assign(:pens, pens)
     |> assign(:pen_names, Map.new(pens, &{&1.id, &1.name}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = if params["status"] in @statuses, do: params["status"], else: "active"
    pen = Enum.find(socket.assigns.pens, &(to_string(&1.id) == params["pen"]))

    opts = [status: String.to_existing_atom(status)] ++ if(pen, do: [pen: pen], else: [])

    animals =
      for animal <- Herd.list_animals(opts), do: {animal, Herd.latest_weight(animal)}

    {:noreply, assign(socket, status: status, pen: pen, animals: animals)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query = Map.take(params, ["status", "pen"]) |> Enum.reject(fn {_, v} -> v == "" end)
    {:noreply, push_patch(socket, to: ~p"/animals?#{query}")}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :statuses, @statuses)

    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Animals
        <:actions>
          <.button navigate={~p"/animals/new"} variant="primary">
            <.icon name="hero-plus" /> Register animal
          </.button>
        </:actions>
      </.header>

      <form id="animal-filter" phx-change="filter" class="flex flex-wrap gap-2">
        <select name="status" class="select select-sm w-auto">
          <option :for={s <- @statuses} value={s} selected={s == @status}>
            {String.capitalize(s)}
          </option>
        </select>
        <select name="pen" class="select select-sm w-auto">
          <option value="">All pens</option>
          <option :for={p <- @pens} value={p.id} selected={@pen && @pen.id == p.id}>
            {p.name}
          </option>
        </select>
      </form>

      <p :if={@animals == []} class="text-base-content/70">No animals match.</p>

      <.table
        :if={@animals != []}
        id="animals"
        rows={@animals}
        row_id={fn {a, _} -> "animal-#{a.id}" end}
        row_click={fn {a, _} -> JS.navigate(~p"/animals/#{a}") end}
      >
        <:col :let={{a, _}} label="Tag">{a.tag}</:col>
        <:col :let={{a, _}} label="Breed">{a.breed}</:col>
        <:col :let={{a, _}} label="Sex">{label(a.sex)}</:col>
        <:col :let={{a, _}} label="Pen">{Map.get(@pen_names, a.pen_id, "—")}</:col>
        <:col :let={{a, _}} label="Arrived">{date(a.arrival_date)}</:col>
        <:col :let={{_, weight}} label="Latest weight">{lb(weight)}</:col>
        <:col :let={{a, _}} label="Status">
          <span class={status_badge(a.status)}>{label(a.status)}</span>
        </:col>
      </.table>
    </Layouts.app>
    """
  end
end
