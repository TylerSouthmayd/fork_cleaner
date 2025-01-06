import Config

config :fork_cleaner,
  github_token:
    System.get_env("GITHUB_ACCESS_TOKEN") ||
      raise("""
      environment variable GITHUB_ACCESS_TOKEN is missing.
      Please set the environment variable or check that it's properly exported.
      """),
  github_host: System.get_env("GITHUB_HOST") || "https://api.github.com"
