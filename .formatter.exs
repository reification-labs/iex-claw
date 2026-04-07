[
  inputs: [
    "{mix,.formatter,.credo}.exs",
    "{lib,test}/**/*.{ex,exs}",
    "agents/*/*.exs",
    "agents/shared/*.exs",
    "agents/heartbeat.exs"
  ],
  line_length: 120,
  # Styler plugin — consistent formatting beyond base mix format
  plugins: [Styler]
]
