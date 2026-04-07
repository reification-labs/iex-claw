defmodule IExClaw.Tools.EditFile do
  @moduledoc """
  Targeted, atomic edits: a list of `{old_text, new_text}` pairs, where each
  `old_text` must appear EXACTLY ONCE in the file. Validates all edits first,
  then applies them together. "Specs are contracts, not documentation."

  Extracted from agents/code/code.exs on 2026-04-05.
  """

  alias IExClaw.Tools.FileSystem
  alias IExClaw.Tools.ScopeGuard

  @type edit :: %{old_text: String.t(), new_text: String.t()} | %{String.t() => String.t()}
  @type result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Apply `edits` to the file at `path`, scoped to `workplace`.

  Each edit's `old_text` must appear EXACTLY ONCE in the file. If any edit
  fails validation, none are applied.
  """
  @spec edit(Path.t(), Path.t(), [edit]) :: result
  def edit(path, workplace, edits) when is_list(edits) do
    normalized = Enum.map(edits, &normalize/1)

    with {:ok, expanded} <- ScopeGuard.validate(path, workplace),
         {:ok, original} <- FileSystem.read_file_raw(expanded, workplace),
         :ok <- validate_edits(normalized, original) do
      new_content = apply_edits(original, normalized)
      File.write!(expanded, new_content)

      {:ok,
       "Applied #{length(normalized)} edit(s) to #{expanded} " <>
         "(#{byte_size(original)} → #{byte_size(new_content)} bytes)"}
    end
  end

  # -- private --

  @spec normalize(edit) :: %{old_text: String.t(), new_text: String.t()}
  defp normalize(edit) do
    %{
      old_text: Map.get(edit, "old_text") || Map.get(edit, :old_text),
      new_text: Map.get(edit, "new_text") || Map.get(edit, :new_text)
    }
  end

  @spec validate_edits([map()], binary()) :: :ok | {:error, String.t()}
  defp validate_edits(edits, content) do
    errors =
      edits
      |> Enum.with_index()
      |> Enum.flat_map(fn {%{old_text: old_text}, idx} ->
        case count_occurrences(content, old_text) do
          0 -> ["Edit #{idx}: oldText not found in file"]
          1 -> []
          n -> ["Edit #{idx}: oldText appears #{n} times (must be unique)"]
        end
      end)

    if errors == [] do
      :ok
    else
      {:error, "Edit validation failed:\n" <> Enum.join(errors, "\n")}
    end
  end

  @spec apply_edits(binary(), [map()]) :: binary()
  defp apply_edits(content, edits) do
    Enum.reduce(edits, content, fn %{old_text: old, new_text: new}, acc ->
      String.replace(acc, old, new)
    end)
  end

  @spec count_occurrences(binary(), binary()) :: non_neg_integer()
  defp count_occurrences(content, substring), do: do_count(content, substring, 0)

  defp do_count(content, substring, acc) do
    case :binary.match(content, substring) do
      :nomatch ->
        acc

      {pos, len} ->
        rest = binary_part(content, pos + len, byte_size(content) - pos - len)
        do_count(rest, substring, acc + 1)
    end
  end
end
