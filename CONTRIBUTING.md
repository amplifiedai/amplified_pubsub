# Contributing to Amplified.PubSub

Thanks for your interest in contributing to this project! Please
read through this guide and our [Code of Conduct](CODE_OF_CONDUCT.md)
before getting started.

## Reporting Bugs

Before opening a bug report, search existing issues to avoid duplicates and
try reproducing against the `main` branch. A good report includes:

- Your Elixir, Erlang/OTP, Phoenix, LiveView, and `amplified_pubsub` versions
- Steps to reproduce the problem
- What you expected vs what actually happened
- A minimal code sample or test case if possible

## Suggesting Features

Feature ideas are welcome as GitHub issues. Please explain the use case and
why the feature belongs in this library rather than in application code.

## Writing Documentation

We follow standard Elixir documentation conventions:

- `@moduledoc` should open with a one-line summary of what the module _is_
- `@doc` should open with a one-line summary of what the function _does_
- Keep first paragraphs short — they appear in summary listings
- Include doctests where practical so examples stay correct over time

## Submitting Pull Requests

For anything beyond a small fix, open an issue first to discuss the approach.

To contribute code:

1. Fork the repo and create a topic branch from `main`
2. Write your changes along with any relevant tests
3. Run `mix test` and `mix format` before committing
4. Keep commits focused — one logical change per commit
5. Open a PR with a clear description of what changed and why

When keeping a long-lived branch up to date, rebase onto `main` rather than
merging it in.

By submitting a PR, you agree that your contribution will be licensed under
the project's [MIT Licence](LICENCE.md).
