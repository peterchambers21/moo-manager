defmodule CattleWeb.AnimalLive.Form do
  use CattleWeb, :live_view

  alias Cattle.Herd
  alias Cattle.Herd.Animal

  @sexes [{"Steer", :steer}, {"Heifer", :heifer}, {"Bull", :bull}, {"Cow", :cow}]

  @impl true
  def mount(params, _session, socket) do
    animal =
      case socket.assigns.live_action do
        :new -> %Animal{arrival_date: Date.utc_today(), pen_id: parse_id(params["pen"])}
        :edit -> Herd.get_animal!(params["id"])
      end

    {:ok,
     socket
     |> assign(:animal, animal)
     |> assign(:page_title, if(animal.id, do: "Edit #{animal.tag}", else: "Register animal"))
     |> assign(:pen_options, Enum.map(Herd.list_pens(), &{&1.name, &1.id}))
     |> assign(:sexes, @sexes)
     |> assign(:form, to_form(Herd.change_animal(animal)))}
  end

  defp parse_id(nil), do: nil

  defp parse_id(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  @impl true
  def handle_event("validate", %{"animal" => params}, socket) do
    changeset = Herd.change_animal(socket.assigns.animal, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"animal" => params}, socket) do
    result =
      if socket.assigns.animal.id,
        do: Herd.update_animal(socket.assigns.animal, params),
        else: Herd.register_animal(params)

    case result do
      {:ok, animal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved #{animal.tag}.")
         |> push_navigate(to: ~p"/animals/#{animal}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>{@page_title}</.header>

      <.form
        for={@form}
        id="animal-form"
        phx-change="validate"
        phx-submit="save"
        class="grid max-w-2xl gap-x-4 sm:grid-cols-2"
      >
        <.input field={@form[:tag]} label="Ear tag" />
        <.input field={@form[:breed]} label="Breed" />
        <.input field={@form[:sex]} type="select" label="Sex" prompt="Unknown" options={@sexes} />
        <.input field={@form[:source]} label="Source" placeholder="Seller or ranch" />
        <.input field={@form[:birth_date]} type="date" label="Birth date" />
        <.input field={@form[:arrival_date]} type="date" label="Arrival date" />
        <%!-- Pen changes for existing animals go through "Move" so departed animals stay put. --%>
        <.input
          :if={!@animal.id}
          field={@form[:pen_id]}
          type="select"
          label="Pen"
          prompt="No pen"
          options={@pen_options}
        />
        <.input
          :if={!@animal.id}
          field={@form[:arrival_weight_lb]}
          type="number"
          step="0.1"
          label="Arrival weight (lb)"
        />
        <div class="sm:col-span-2">
          <.input field={@form[:notes]} type="textarea" label="Notes" />
        </div>
        <div class="mt-4 flex gap-2 sm:col-span-2">
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
          <.button navigate={if @animal.id, do: ~p"/animals/#{@animal}", else: ~p"/animals"}>
            Cancel
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
