# Coding standards

## Best practices

Ensure proper use of:

- Pattern matching and guard clauses
- GenServer/Agent/Task patterns whenever appropriate
- Proper OTP principles
- Ecto query optimization
- Phoenix LiveView patterns

### Ecto queries

When working with Ecto queries, always place queries in the appropriate backend context modules. Never write Ecto queries directly in controllers or LiveViews. This maintains proper separation of concerns and follows Phoenix/Elixir best practices.

## Style guide

Follow standard Elixir Style Guide: https://github.com/rrrene/elixir-style-guide

## Library guidelines

Follow library guidelines: https://hexdocs.pm/elixir/1.18.4/library-guidelines.html

