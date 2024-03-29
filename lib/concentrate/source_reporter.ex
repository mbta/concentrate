defmodule Concentrate.SourceReporter do
  @moduledoc """
  Reporter: log statistics or other information for each source

  This module defines an interface to output statistical data about the
  source data of Concentrate. It receives a `FeedUpdate.t()` generated by a source
  and returns stats and an updated state.

  ## Callbacks

  * `init/0`: returns an initial state
  * `log/2`: receives a `FeedUpdate.t()` and the current state;
    returns a keyword list of stats and the new state
  """
  @type state :: term
  @type stats :: [{atom, term}]

  @callback init() :: state
  @callback log(Concentrate.FeedUpdate.t(), state) :: {stats, state}
end
