# IExClaw.TickRefactor
#
# PlanExecute-powered tick harness for agent self-refactoring.
#
# "Make the change easy (warning: this may be hard), then make the easy change."
# — Kent Beck
#
# Usage:
#   elixir agents/tick_refactor.exs --agent code --goal "Rewire ToolRegistry to delegate to IExClaw.ToolRegistry"
#   elixir agents/tick_refactor.exs --agent code --goal "..." --dry-run
#   elixir agents/tick_refactor.exs --agent code --goal "..." --survey-budget 3 --execute-budget 10 --verify-budget 2
#
# Phases:
#   1. Survey — Agent reads its own files, outputs a plan (JSON steps)
#   2. Execute — One step per tick, each a narrow edit
#   3. Verify — Agent checks the result
#
# Budget protects against infinite loops. Each phase has its own ceiling.

Mix.install([
  {:req, "~> 0.5"},
  {:jason, "~> 1.4"}
])

# Load compiled lib/ modules
for mod <- ~w[
  scope_guard file_system edit_file messages agent_logger
] do
  Code.require_file(Path.expand("../lib/iex_claw/tools/#{mod}.ex", __DIR__))
end

Code.require_file(Path.expand("../lib/iex_claw/tool_registry.ex", __DIR__))
Code.require_file(Path.expand("../lib/iex_claw/llm_client.ex", __DIR__))
Code.require_file(Path.expand("../lib/iex_claw/strategies/plan_execute.ex", __DIR__))
Code.require_file(Path.expand("../lib/iex_claw/mode.ex", __DIR__))
Code.require_file(Path.expand("../lib/iex_claw/contract.ex", __DIR__))
Code.require_file(Path.expand("../lib/iex_claw/tools/submit_plan.ex", __DIR__))

# --- Scoped tool wrappers ---

defmodule TickRefactor.Tools do
  @moduledoc "Scope-guarded tools for the refactor agent."
  @workplace Path.expand("projects/iex-claw", System.get_env("HOME") <> "/workspace")

  def read_file(path, offset \\ 0, limit \\ 8000),
    do: IExClaw.Tools.FileSystem.read_file(path, @workplace, offset, limit)

  def write_file(path, content, overwrite \\ false),
    do: IExClaw.Tools.FileSystem.write_file(path, @workplace, content, overwrite)

  def edit_file(path, edits),
    do: IExClaw.Tools.EditFile.edit(path, @workplace, edits)

  def list_dir(path),
    do: IExClaw.Tools.FileSystem.list_dir(path, @workplace)

  def file_size(path),
    do: IExClaw.Tools.FileSystem.file_size(path, @workplace)
end

# --- The harness ---

defmodule IExClaw.TickRefactor do
  alias IExClaw.Strategies.PlanExecute

  @tools %{
    "read_file" =>
      {TickRefactor.Tools, :read_file, "Read file contents (sliced). Banner + slice.",
       [
         %{name: "path", type: "string", description: "File path"},
         %{name: "offset", type: "integer", description: "Byte offset (default 0)"},
         %{name: "limit", type: "integer", description: "Max bytes (default 8000, 0=whole)"}
       ]},
    "write_file" =>
      {TickRefactor.Tools, :write_file, "Write content to a file. Creates parent dirs.",
       [
         %{name: "path", type: "string", description: "Path"},
         %{name: "content", type: "string", description: "Content"},
         %{name: "overwrite", type: "boolean", description: "Overwrite existing?"}
       ]},
    "edit_file" =>
      {TickRefactor.Tools, :edit_file, "Targeted edits. Each old_text must be unique. Atomic.",
       [
         %{name: "path", type: "string", description: "File to edit"},
         %{name: "edits", type: "array", description: "List of {old_text, new_text}"}
       ]},
    "list_dir" =>
      {TickRefactor.Tools, :list_dir, "List directory contents (sorted)",
       [%{name: "path", type: "string", description: "Directory path"}]},
    "file_size" =>
      {TickRefactor.Tools, :file_size, "Get file size in bytes",
       [%{name: "path", type: "string", description: "File path"}]}
  }

  @optional_params ["overwrite", "offset", "limit"]

  defstruct [
    :agent_name,
    :model,
    :api_key,
    :base_url,
    :strategy,
    :dry_run,
    survey_budget: 3,
    execute_budget: 15,
    verify_budget: 3,
    total_ticks: 0
  ]

  def run(opts) do
    agent = Keyword.fetch!(opts, :agent)
    goal = Keyword.fetch!(opts, :goal)

    state = %__MODULE__{
      agent_name: agent,
      model: System.get_env("PROJECT_MODEL") || "z-ai/glm-5-turbo",
      api_key: System.get_env("OPENROUTER_API_KEY") || raise("No OPENROUTER_API_KEY"),
      base_url: "https://openrouter.ai/api/v1",
      strategy: PlanExecute.new(goal),
      dry_run: Keyword.get(opts, :dry_run, false),
      survey_budget: Keyword.get(opts, :survey_budget, 3),
      execute_budget: Keyword.get(opts, :execute_budget, 15),
      verify_budget: Keyword.get(opts, :verify_budget, 3)
    }

    IO.puts("""

    🔧 TickRefactor — PlanExecute-powered self-surgery
    ──────────────────────────────────────────────────
      Agent:    #{agent}
      Goal:     #{goal}
      Model:    #{state.model}
      Dry run:  #{state.dry_run}
      Budgets:  survey=#{state.survey_budget} execute=#{state.execute_budget} verify=#{state.verify_budget}
    ──────────────────────────────────────────────────
    """)

    state |> run_survey() |> run_execute() |> run_verify() |> report()
  end

  # ── Survey ──────────────────────────────────────────
  # Mode-constrained: Code gets read_file + list_dir + file_size + submit_plan
  # No edit_file, no write_file. "The phone is in another room."

  @survey_mode IExClaw.Mode.new(:survey,
    tools: [:read_file, :list_dir, :file_size, :submit_plan],
    output: :json_plan,
    next: :execute,
    max_budget: 5,
    description: "Read maps, plan the refactor, submit plan via submit_plan tool"
  )

  defp run_survey(%{strategy: %{phase: :survey}} = state) do
    IO.puts("\n📋 PHASE 1: Survey — Mode: #{@survey_mode.name}")
    IO.puts("   Tools: #{Enum.join(@survey_mode.tools, ", ")}")
    IO.puts("   Exit gate: submit_plan (ONLY way to advance)\n")

    survey_tools = build_survey_tools()
    prompt = survey_prompt(state)
    {_response, plan_result, state} = llm_loop_with_capture(state, prompt, state.survey_budget, survey_tools)

    case plan_result do
      {:ok, steps} ->
        IO.puts("\n   ✅ Survey complete! #{length(steps)} steps planned:")
        Enum.each(steps, fn s -> IO.puts("      • [#{s["id"]}] #{s["task"]}") end)

        strategy =
          state.strategy
          |> PlanExecute.set_survey_result("plan submitted via tool")
          |> PlanExecute.set_plan(normalize_steps(steps))
          |> PlanExecute.begin_execution()

        %{state | strategy: strategy}

      nil ->
        IO.puts("\n   ❌ Survey failed: Agent never called submit_plan")
        IO.puts("   (This means the mode constraint worked — agent couldn't exit without a plan)")
        %{state | strategy: PlanExecute.finish(state.strategy)}
    end
  end

  defp run_survey(state), do: state

  defp build_survey_tools do
    base = Path.expand("~/workspace/projects/iex-claw")

    %{
      "read_file" =>
        {TickRefactor.Tools, :read_file, "Read file contents (sliced). Use to read maps and specific sections.",
         [%{name: "path", type: "string", description: "Absolute file path"},
          %{name: "offset", type: "integer", description: "Byte offset (default 0)"},
          %{name: "limit", type: "integer", description: "Max bytes (default 8000, 0=whole)"}]},
      "list_dir" =>
        {TickRefactor.Tools, :list_dir, "List directory contents",
         [%{name: "path", type: "string", description: "Absolute directory path"}]},
      "file_size" =>
        {TickRefactor.Tools, :file_size, "Get file size in bytes",
         [%{name: "path", type: "string", description: "Absolute file path"}]},
      "submit_plan" =>
        {IExClaw.Tools.SubmitPlan, :submit,
         "Submit your refactor plan. This is the ONLY way to complete the survey phase. " <>
         "Pass a JSON string: array of step objects, each with 'id' and 'task' fields. " <>
         "Optional: 'files' (array of paths) and 'lines' (string like '156-270'). " <>
         "Example: [{\"id\":\"step-1\",\"task\":\"Replace as_openai_tools body\",\"files\":[\"agents/code/code.exs\"],\"lines\":\"225-248\"}]",
         [%{name: "plan_json", type: "string", description: "JSON array of step objects"}]}
    }
  end

  # ── Execute ─────────────────────────────────────────

  defp run_execute(%{strategy: %{phase: :execute}} = state) do
    IO.puts("\n⚡ PHASE 2: Execute (budget=#{state.execute_budget})")
    execute_loop(state, 0)
  end

  defp run_execute(state), do: state

  defp execute_loop(state, used) when used >= state.execute_budget do
    left = PlanExecute.steps_total(state.strategy) - PlanExecute.steps_done(state.strategy)
    IO.puts("\n   ⛔ Execute budget exhausted (#{used}/#{state.execute_budget}). #{left} steps remaining.")
    state
  end

  defp execute_loop(state, used) do
    case PlanExecute.current_step(state.strategy) do
      nil ->
        IO.puts("\n   ✅ All #{PlanExecute.steps_total(state.strategy)} steps done!")
        %{state | strategy: PlanExecute.begin_verification(state.strategy)}

      step ->
        IO.puts("\n   🔨 Step [#{step.id}] (#{used + 1}/#{state.execute_budget}): #{step.task}")

        if state.dry_run do
          IO.puts("      [DRY RUN] skipped")
          execute_loop(%{state | strategy: PlanExecute.complete_step(state.strategy, "[dry]")}, used + 1)
        else
          prompt = step_prompt(state, step)
          {response, state} = llm_loop(state, prompt, 1)

          strategy =
            if response && String.contains?(response, "ERROR") do
              IO.puts("      ⚠️  Step had issues")
              PlanExecute.fail_step(state.strategy, String.slice(response, 0, 500))
            else
              IO.puts("      ✅ Step done")
              PlanExecute.complete_step(state.strategy, response || "")
            end

          execute_loop(%{state | strategy: strategy}, used + 1)
        end
    end
  end

  # ── Verify ──────────────────────────────────────────

  defp run_verify(%{strategy: %{phase: :verify}} = state) do
    IO.puts("\n🧪 PHASE 3: Verify (budget=#{state.verify_budget})")
    prompt = verify_prompt(state)
    {response, state} = llm_loop(state, prompt, state.verify_budget)

    strategy =
      state.strategy
      |> PlanExecute.set_verify_result(response || "")
      |> PlanExecute.finish()

    %{state | strategy: strategy}
  end

  defp run_verify(state), do: state

  # ── Report ──────────────────────────────────────────

  defp report(state) do
    s = state.strategy
    err_block = if s.errors != [], do: Enum.map_join(s.errors, "\n", &("      • " <> String.slice(&1, 0, 200))), else: "(none)"

    IO.puts("""

    ──────────────────────────────────────────────────
    📊 TickRefactor Report
    ──────────────────────────────────────────────────
      Agent:       #{state.agent_name}
      Goal:        #{s.goal}
      Final phase: #{PlanExecute.phase(s)}
      Progress:    #{PlanExecute.progress(s)}
      Total ticks: #{state.total_ticks}
      Errors:      #{err_block}
    ──────────────────────────────────────────────────
    """)

    state
  end

  # ── LLM Loop (with plan capture for survey mode) ────

  defp llm_loop_with_capture(state, prompt, max_rounds, tools) do
    openai_tools = IExClaw.ToolRegistry.as_openai_tools(tools, @optional_params)
    messages = [
      %{"role" => "system", "content" => "You are an Elixir agent in SURVEY MODE. You can read files and submit a plan. You CANNOT edit or write files. When you have enough information, call submit_plan with your JSON plan. That is the ONLY way to complete this phase."},
      %{"role" => "user", "content" => prompt}
    ]
    do_llm_round_capture(state, messages, openai_tools, tools, max_rounds, 0, nil)
  end

  defp do_llm_round_capture(state, messages, _ot, _tools, max, n, plan_result) when n >= max do
    IO.puts("   ⛔ Survey budget exhausted (#{n}/#{max})")
    last = messages |> Enum.reverse() |> Enum.find(&(&1["role"] == "assistant"))
    {last && last["content"], plan_result, bump_ticks(state, n)}
  end

  defp do_llm_round_capture(state, messages, openai_tools, tools, max, n, plan_result) do
    total_calls = Enum.count(messages, &(&1["role"] in ["assistant", "tool"]))
    hard_cap = max * 8
    if total_calls > hard_cap do
      IO.puts("   ⛔ Hard cap reached (#{total_calls} calls)")
      {nil, plan_result, bump_ticks(state, n)}
    else
      IO.puts("   ⏳ Round #{n + 1}/#{max} (#{total_calls} calls)...")

      case IExClaw.LLMClient.call(state.model, messages, openai_tools, api_key: state.api_key, base_url: state.base_url) do
        {:tool_calls, tool_calls, assistant_msg} ->
          names = Enum.map_join(tool_calls, ", ", & &1["function"]["name"])
          IO.puts("   🔧 #{names}")

          {results, captured} = Enum.map_reduce(tool_calls, plan_result, fn tc, acc ->
            name = tc["function"]["name"]
            args = Jason.decode!(tc["function"]["arguments"])
            IO.puts("      → #{name}(#{short_args(args)})")

            result = case IExClaw.ToolRegistry.execute(tools, name, args) do
              {:ok, v} ->
                new_acc = if name == "submit_plan", do: {:ok, v}, else: acc
                {inspect(v, limit: :infinity, printable_limit: :infinity), new_acc}
              {:error, r} ->
                {"ERROR: #{r}", acc}
              other ->
                {inspect(other, limit: :infinity, printable_limit: :infinity), acc}
            end

            {result_str, new_acc} = result
            IO.puts("      ← #{String.slice(result_str, 0, 120)}")
            {%{"role" => "tool", "tool_call_id" => tc["id"], "content" => result_str}, new_acc}
          end)

          # If submit_plan succeeded, we're done — don't need more rounds
          if captured != nil and captured != plan_result do
            IO.puts("   🎯 Plan submitted via submit_plan tool!")
            {nil, captured, bump_ticks(state, n + 1)}
          else
            do_llm_round_capture(state, messages ++ [assistant_msg] ++ results, openai_tools, tools, max, n, captured)
          end

        {:message, content} ->
          IO.puts("   🧬 #{String.slice(content, 0, 200)}")
          {content, plan_result, bump_ticks(state, n + 1)}

        {:error, reason} ->
          IO.puts("   ❌ LLM error: #{inspect(reason)}")
          {nil, plan_result, bump_ticks(state, n + 1)}
      end
    end
  end

  # ── LLM Loop (standard, for execute/verify) ────────

  defp llm_loop(state, prompt, max_rounds) do
    openai_tools = IExClaw.ToolRegistry.as_openai_tools(@tools, @optional_params)

    messages = [
      %{"role" => "system", "content" => "You are an Elixir agent performing a planned refactor. Use tools to read and edit files. Stay focused on the current task. Be concise."},
      %{"role" => "user", "content" => prompt}
    ]

    do_llm_round(state, messages, openai_tools, max_rounds, 0)
  end

  defp do_llm_round(state, messages, _tools, max, n) when n >= max do
    IO.puts("   ⛔ Round budget exhausted (#{n}/#{max})")
    last = messages |> Enum.reverse() |> Enum.find(&(&1["role"] == "assistant"))
    {last && last["content"], bump_ticks(state, n)}
  end

  # Note: tool-call rounds DON'T count against budget — only final message rounds do.
  # This lets the agent read as much as it needs before planning.
  # The budget caps how many THINKING rounds (tool-call → response cycles) it gets.
  defp do_llm_round(state, messages, openai_tools, max, n) do
    # Safety valve: hard cap on total LLM calls (tool rounds + message rounds)
    # Prevents infinite loops where model keeps calling tools without concluding
    hard_cap = max * 12  # generous — steps may need 3-4 tool rounds each
    total_calls = Enum.count(messages, &(&1["role"] in ["assistant", "tool"]))
    if total_calls > hard_cap do
      IO.puts("   ⛔ Hard cap reached (#{total_calls} total calls, cap=#{hard_cap})")
      last = messages |> Enum.reverse() |> Enum.find(&(&1["role"] == "assistant"))
      {last && last["content"], bump_ticks(state, n)}
    else
      IO.puts("   ⏳ Round #{n + 1}/#{max} (#{total_calls} total calls)...")

    case IExClaw.LLMClient.call(state.model, messages, openai_tools, api_key: state.api_key, base_url: state.base_url) do
      {:tool_calls, tool_calls, assistant_msg} ->
        names = Enum.map_join(tool_calls, ", ", & &1["function"]["name"])
        IO.puts("   🔧 #{names}")

        results =
          Enum.map(tool_calls, fn tc ->
            name = tc["function"]["name"]
            args = Jason.decode!(tc["function"]["arguments"])
            IO.puts("      → #{name}(#{short_args(args)})")

            result =
              case IExClaw.ToolRegistry.execute(@tools, name, args) do
                {:ok, v} -> inspect(v, limit: :infinity, printable_limit: :infinity)
                {:error, r} -> "ERROR: #{r}"
                other -> inspect(other, limit: :infinity, printable_limit: :infinity)
              end

            IO.puts("      ← #{String.slice(result, 0, 120)}")
            %{"role" => "tool", "tool_call_id" => tc["id"], "content" => result}
          end)

        # Tool-call rounds are FREE — don't increment n (the thinking budget)
        do_llm_round(state, messages ++ [assistant_msg] ++ results, openai_tools, max, n)

      {:message, content} ->
        IO.puts("   🧬 #{String.slice(content, 0, 200)}")
        # Only final messages count against budget
        {content, bump_ticks(state, n + 1)}

      {:error, reason} ->
        IO.puts("   ❌ LLM error: #{inspect(reason)}")
        {nil, bump_ticks(state, n + 1)}
    end
    end  # close the else from hard_cap check
  end

  defp bump_ticks(state, n), do: %{state | total_ticks: state.total_ticks + n}

  # ── Prompts ─────────────────────────────────────────

  defp survey_prompt(state) do
    # Resolve map paths based on agent
    {section_map, lib_map} = map_paths(state.agent_name)

    """
    You are #{state.agent_name}, planning a refactor of your own body.

    GOAL: #{state.strategy.goal}

    IMPORTANT: Do NOT explore the filesystem. Maps have already been generated for you.

    STEP 1: Read the section map (has your file's structure, byte offsets, line numbers):
      read_file("#{section_map}")

    STEP 2: Read the lib/ module index (has all shared module APIs):
      read_file("#{lib_map}")

    STEP 3: If you need to see a specific section of your file, use offset/limit
    from the map. Do NOT read the whole file.

    STEP 4: Output a PLAN as a JSON array. Each step = ONE edit_file call.

    OUTPUT FORMAT (you MUST include this JSON block in your final message):
    ```json
    [
      {"id": "step-1", "task": "SHORT DESCRIPTION", "files": ["path/to/file"], "lines": "START-END"},
      {"id": "step-2", "task": "SHORT DESCRIPTION", "files": ["path/to/file"], "lines": "START-END"}
    ]
    ```

    RULES:
    - Each step = ONE edit_file call (one old_text/new_text pair)
    - Use the byte offsets from the section map for precise reads in execute phase
    - Order: independent changes first, dependent last
    - Do NOT edit files during survey. Read + plan only.
    """
  end

  defp map_paths("code") do
    base = Path.expand("~/workspace/projects/iex-claw")
    {
      Path.join(base, "agents/map/maps/code-exs-sections.md"),
      Path.join(base, "agents/map/maps/lib-iex-claw-modules.md")
    }
  end

  defp map_paths("goal") do
    base = Path.expand("~/workspace/projects/iex-claw")
    {
      Path.join(base, "agents/map/maps/goal-exs-sections.md"),
      Path.join(base, "agents/map/maps/lib-iex-claw-modules.md")
    }
  end

  defp map_paths(_), do: raise("No maps for this agent yet")

  defp step_prompt(state, step) do
    wp = Path.expand("~/workspace/projects/iex-claw")

    files_abs = Enum.map(step.files, fn f ->
      if String.starts_with?(f, "/"), do: f, else: Path.join(wp, f)
    end)

    """
    You are #{state.agent_name}, executing one step of a planned refactor.

    WORKSPACE: #{wp}
    ALL PATHS MUST BE ABSOLUTE (start with #{wp}).

    GOAL: #{state.strategy.goal}
    STEP: #{step.task}
    FILES: #{Enum.join(files_abs, ", ")}
    #{if step.lines, do: "LINES: #{step.lines}", else: ""}

    PROCESS:
    1. read_file the relevant section of #{hd(files_abs)} (use offset/limit)
    2. ONE edit_file call: one old_text/new_text pair
    3. Report what changed

    RULES:
    - ALL paths MUST start with #{wp}/
    - ONE edit_file call only
    - Preserve external arities
    """
  end

  defp verify_prompt(state) do
    done = PlanExecute.steps_done(state.strategy)
    total = PlanExecute.steps_total(state.strategy)

    """
    You are #{state.agent_name}, verifying a refactor.

    GOAL: #{state.strategy.goal}
    COMPLETED: #{done}/#{total} steps (#{length(state.strategy.errors)} errors)

    VERIFY (read only — do NOT edit):
    1. read_file the top ~1000 bytes (check Code.require_file lines)
    2. Read around changed sections to confirm delegations
    3. file_size to confirm file got smaller
    4. Report: complete? issues? recommended next steps?
    """
  end

  # ── Helpers ─────────────────────────────────────────

  defp extract_plan(nil), do: {:error, "No response"}

  defp extract_plan(response) do
    case Regex.run(~r/```json\s*\n(\[[\s\S]*?\])\s*\n```/, response) do
      [_, json] ->
        Jason.decode(json)

      nil ->
        case Regex.run(~r/(\[\s*\{[\s\S]*\}\s*\])/, response) do
          [_, json] -> Jason.decode(json)
          nil -> {:error, "No JSON plan found"}
        end
    end
  end

  defp normalize_steps(steps) do
    Enum.map(steps, fn s ->
      %{
        id: s["id"] || "step-#{System.unique_integer([:positive])}",
        task: s["task"] || "",
        files: s["files"] || [],
        lines: s["lines"]
      }
    end)
  end

  defp short_args(args) when is_map(args) do
    Enum.map_join(args, ", ", fn {k, v} ->
      val = if is_binary(v) and byte_size(v) > 60, do: "#{String.slice(v, 0, 57)}...", else: inspect(v, limit: 3)
      "#{k}: #{val}"
    end)
  end
end

# ── CLI ───────────────────────────────────────────────

opts =
  System.argv()
  |> Enum.chunk_every(2, 1, [nil])
  |> Enum.reduce(%{agent: "code", goal: nil, dry_run: false, survey_budget: 3, execute_budget: 15, verify_budget: 3}, fn
    ["--agent", v], acc when is_binary(v) -> %{acc | agent: v}
    ["--goal", v], acc when is_binary(v) -> %{acc | goal: v}
    ["--dry-run" | _], acc -> %{acc | dry_run: true}
    ["--survey-budget", v], acc -> %{acc | survey_budget: String.to_integer(v)}
    ["--execute-budget", v], acc -> %{acc | execute_budget: String.to_integer(v)}
    ["--verify-budget", v], acc -> %{acc | verify_budget: String.to_integer(v)}
    _, acc -> acc
  end)

if is_nil(opts.goal) do
  IO.puts("""
  🔧 TickRefactor — PlanExecute self-surgery

  Usage:
    elixir agents/tick_refactor.exs --agent code --goal "Rewire ToolRegistry to use IExClaw.ToolRegistry"

  Options:
    --agent NAME          Agent to refactor (code, goal)
    --goal "DESCRIPTION"  The refactor goal
    --dry-run             Survey + plan only, skip execute
    --survey-budget N     Max LLM rounds for survey (default 3)
    --execute-budget N    Max steps to execute (default 15)
    --verify-budget N     Max LLM rounds for verify (default 3)
  """)
else
  File.cd!(Path.expand("~/workspace"))
  IExClaw.TickRefactor.run(Map.to_list(opts))
end
