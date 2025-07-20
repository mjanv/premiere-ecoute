# Generate module documentation

Analyzes selected Elixir code: $ARGUMENTS and generates appropriate `@moduledoc` or `@doc` documentation with proper markdown formatting. Shows a diff preview before applying changes. Remains as consise and precise as possible, use markdown formatting to be usable in ExDoc. No line return inside a same paragraph.

- **For modules**: Creates `@moduledoc` with clear purpose and usage (if needed).
- **For functions**: Creates `@doc` with title, description paragraph and examples (only if needed). No arguments, parameters or return values should be documented
