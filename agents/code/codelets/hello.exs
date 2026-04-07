# IExClaw.Codelets.Hello
#
# My first codelet. I'm proud of it.
#
# A tiny greeter — proof that the code wants to run.
# Born from the simplest possible request: say hello.

defmodule IExClaw.Codelets.Hello do
  @moduledoc """
  My first codelet, and I'm proud of it.

  A simple greeter module that demonstrates the bare minimum
  of what a living piece of code looks like: one function,
  one purpose, one reason to exist.

  ## Usage

      iex> IExClaw.Codelets.Hello.greet("World")
      "Hello, World!"

  """

  @doc """
  Greets the given name.

  ## Examples

      iex> IExClaw.Codelets.Hello.greet("Clawd")
      "Hello, Clawd!"

  """
  @spec greet(String.t()) :: String.t()
  def greet(name) do
    "Hello, " <> name <> "!"
  end

  @doc """
  Greets the given name, but LOUDLY.

  Delegates to `greet/1`, then uppercases the result
  and swaps the single exclamation mark for three.

  ## Examples

      iex> IExClaw.Codelets.Hello.greet_loud("Clawd")
      "HELLO, CLAWD!!!"

  """
  @spec greet_loud(String.t()) :: String.t()
  def greet_loud(name) do
    name
    |> greet()
    |> String.upcase()
    |> String.trim_trailing("!")
    |> Kernel.<>("!!!")
  end
end
