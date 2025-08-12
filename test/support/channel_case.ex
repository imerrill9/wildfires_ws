defmodule WildfiresWsWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  It imports `Phoenix.ChannelTest` and sets the default
  `@endpoint` for testing.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use WildfiresWsWeb, :verified_routes

      # The default endpoint for testing
      @endpoint WildfiresWsWeb.Endpoint

      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import WildfiresWsWeb.ChannelCase
    end
  end

  setup _tags do
    :ok
  end
end
