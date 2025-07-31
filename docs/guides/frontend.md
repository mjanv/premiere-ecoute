# 🎨 Frontend & Design System guide

## Tech stack

Premiere Ecoute uses [DaisyUI components](https://daisyui.com/components/) built on Tailwind CSS for rapid UI development with [Phoenix Storybook](https://github.com/phenixdigital/phoenix_storybook) for component documentation and testing.

## 🚀 Development workflow

### Component development

1. **Design in Storybook** - Visit [http://localhost:4000/storybook](http://localhost:4000/storybook) to explore components and create variations
2. **Build with DaisyUI** - Use component classes instead of writing multiple utility classes
3. **Customize with Tailwind** - Add utilities for spacing, colors, and unique styling

### Creating stories

Create `.story.exs` files in the `storybook/` directory to document your components with different variations and attributes.
