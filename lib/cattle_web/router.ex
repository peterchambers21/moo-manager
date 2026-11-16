defmodule CattleWeb.Router do
  use CattleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CattleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CattleWeb do
    pipe_through :browser

    live "/", DashboardLive, :index

    live "/pens", PenLive.Index, :index
    live "/pens/new", PenLive.Form, :new
    live "/pens/:id", PenLive.Show, :show
    live "/pens/:id/edit", PenLive.Form, :edit

    live "/animals", AnimalLive.Index, :index
    live "/animals/new", AnimalLive.Form, :new
    live "/animals/:id", AnimalLive.Show, :show
    live "/animals/:id/edit", AnimalLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", CattleWeb do
  #   pipe_through :api
  # end
end
