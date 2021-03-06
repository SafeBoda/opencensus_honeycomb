defmodule Opencensus.Honeycomb.Reporter do
  @moduledoc """
  Reporter implementation.

  `:opencensus` calls `report/2` with a list of spans collected over the last `send_interval_ms`.
  `report/2` cuts them into `batch_size` batches for `Opencensus.Honeycomb.Sender.send_batch/1`.
  """

  alias Opencensus.Honeycomb.Config
  alias Opencensus.Honeycomb.Event
  alias Opencensus.Honeycomb.Sender

  @behaviour :oc_reporter

  @impl true
  def init(_args) do
    :ok
  end

  @doc "Implements the `report/2` callback for the `:oc_reporter` behaviour."
  @impl true
  def report(spans, :ok) do
    config = Config.effective()
    service_name = config.service_name
    samplerate_key = config.samplerate_key
    translate = fn span -> Event.from_oc_span(span, service_name, samplerate_key) end

    spans
    |> Enum.map(translate)
    |> Enum.filter(&survived_sampling?/1)
    |> Enum.map(&decorate(&1, config.decorator))
    |> Enum.chunk_every(config.batch_size)
    |> Enum.each(&Sender.send_batch/1)

    :ok
  end

  defp survived_sampling?(%Event{samplerate: 1}), do: true

  defp survived_sampling?(%Event{samplerate: n}) when is_integer(n) and n > 0,
    do: :rand.uniform(n) == 1

  defp survived_sampling?(_), do: false

  @doc false
  @spec decorate(Event.t(), Config.decorator()) :: Event.t()
  def decorate(event, decorator)
  def decorate(event, nil), do: event

  def decorate(event, {module, opts}) do
    data = apply(module, :decorate, [event.data, opts])
    struct!(event, data: data)
  end
end
