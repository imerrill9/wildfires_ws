defmodule WildfiresWs.Test.FakeArcgisClient do
  @moduledoc false

  use Agent

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker
    }
  end

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> [] end)
    :ok
  end

  def push_response(features) when is_list(features) do
    Agent.update(__MODULE__, fn queue -> queue ++ [features] end)
    :ok
  end

  def fetch_all_incidents do
    case Agent.get_and_update(__MODULE__, fn
           [next | rest] -> {{:ok, next}, rest}
           [] -> {{:ok, []}, []}
         end) do
      {:ok, features} -> {:ok, features}
      other -> other
    end
  end
end
