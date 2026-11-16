defmodule CattleWeb.PenLive.Index do
  use CattleWeb, :live_view

  alias Cattle.Herd

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Pens") |> load_pens()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id |> Herd.get_pen!() |> Herd.delete_pen() do
      {:ok, pen} ->
        {:noreply, socket |> put_flash(:info, "Deleted #{pen.name}.") |> load_pens()}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That pen has animals or feed records, so it can't be deleted."
         )}
    end
  end

  defp load_pens(socket) do
    assign(socket, :pens, for(pen <- Herd.list_pens(), do: {pen, Herd.head_count(pen)}))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Pens
        <:actions>
          <.button navigate={~p"/pens/new"} variant="primary">
            <.icon name="hero-plus" /> New pen
          </.button>
        </:actions>
      </.header>

      <p :if={@pens == []} class="text-base-content/70">No pens yet.</p>

      <.table
        :if={@pens != []}
        id="pens"
        rows={@pens}
        row_id={fn {pen, _} -> "pen-#{pen.id}" end}
        row_click={fn {pen, _} -> JS.navigate(~p"/pens/#{pen}") end}
      >
        <:col :let={{pen, _}} label="Name">{pen.name}</:col>
        <:col :let={{pen, count}} label="Head">{head(count, pen.capacity)}</:col>
        <:col :let={{pen, _}} label="Notes">{pen.notes}</:col>
        <:action :let={{pen, _}}>
          <.link navigate={~p"/pens/#{pen}/edit"}>Edit</.link>
        </:action>
        <:action :let={{pen, _}}>
          <.link phx-click="delete" phx-value-id={pen.id} data-confirm="Delete #{pen.name}?">
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end
end
