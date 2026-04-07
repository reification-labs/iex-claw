# Credo config — CONSISTENCY ONLY, per Elder Truman's Round Table wisdom:
# "Don't start strict + 40 checks on day one. You'll spend your first sprint
#  playing whack-a-mole instead of shipping."
#
# Add design checks one at a time when the codebase earns the right to care
# about them. strict: false on purpose.
#
# Source: /Users/clawd/workspace/projects/iex-claw/roundtable/2026-04-05_iexclaw-truman-convergence.conversation.md

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "agents/**/*.exs"],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/",
          ~r"/agents/vendors/",
          ~r"\.backup\."
        ]
      },
      plugins: [],
      requires: [],
      # strict: false on purpose. This codebase hasn't earned --strict yet.
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          # Consistency — the ONLY bucket fully enabled on day one.
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Warnings — real bugs, not taste. Keep these on.
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},

          # Minimal Readability — just the essentials to catch obvious bugs.
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.Semicolons, []}
        ],
        # Everything else starts disabled. Promote individual checks
        # (AliasOrder, MaxLineLength, MapJoin, CyclomaticComplexity, etc.)
        # as the codebase matures. DO NOT bulk-enable.
        disabled: []
      }
    }
  ]
}
