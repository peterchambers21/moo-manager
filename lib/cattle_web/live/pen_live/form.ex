defmodule CattleWeb.PenLive.Form do
  use CattleWeb, :live_view

  alias Cattle.Herd
  alias Cattle.Herd.Pen

  @impl true
  def mount(params, _session, socket) do
    pen =
      case socket.assigns.live_action do
        :new -> %Pen{}
        :edit -> Herd.get_pen!(params["id"])
      end

    {:ok,
     socket
     |> assign(:pen, pen)
     |> assign(:page_title, if(pen.id, do: "Edit #{pen.name}", else: "New pen"))
     |> assign(:form, to_form(Herd.change_pen(pen)))}
  end

  @impl true
  def handle_event("validate", %{"pen" => params}, socket) do
    changeset = Herd.change_pen(socket.assigns.pen, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"pen" => params}, socket) do
    result =
      if socket.assigns.pen.id,
        do: Herd.update_pen(socket.assigns.pen, params),
        else: Herd.create_pen(params)

    case result do
      {:ok, pen} ->
        {:noreply,
         socket |> put_flash(:info, "Saved #{pen.name}.") |> push_navigate(to: ~p"/pens/#{pen}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>{@page_title}</.header>

      <.form for={@form} id="pen-form" phx-change="validate" phx-submit="save" class="max-w-md">
        <.input field={@form[:name]} label="Name" />
        <.input
          field={@form[:capacity]}
          type="number"
          label="Capacity (head)"
          placeholder="Leave blank for unlimited"
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <div class="mt-4 flex gap-2">
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
          <.button navigate={if @pen.id, do: ~p"/pens/#{@pen}", else: ~p"/pens"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
