defmodule WildfiresWsWeb.PageController do
  use WildfiresWsWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/index.html")
  end
end
