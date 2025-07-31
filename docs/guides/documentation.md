# 🏛️ Documentation guide

This guide explains how to generate and maintain various types of documentation in the Premiere Ecoute project.

## 👩‍💻 Developer documentation

The project uses [ExDoc](https://github.com/elixir-lang/ex_doc) to generate developer documentation from module and function documentation. All documentation from `@moduledoc` and `@doc` annotation are included. All markdown files located in `docs/` and `README.md`are also included.

```bash
mix docs                    # Check documentation quality, generate HTML & Epub documentation
firefox priv/doc/index.html # Open webpage
```

Documentation quality can be checked using [Doctor](https://github.com/akoutmos/doctor) with the command `mix doctor`.

## 👩‍⚖️ Legal documentation

Legal documents are stored in `priv/legal/` and automatically served as HTML pages via the router through the `legal/` scope.

```
priv/legal/
├── contact.md     # Contact information
├── cookies.md     # Cookie policy
├── privacy.md     # Privacy policy (GDPR compliant)
└── terms.md       # Terms of service
```

Legal documents use a special frontmatter format documented in [NimblePublisher](https://github.com/dashbitco/nimble_publisher). When making significant changes, do not forget to update `version` and `date` in frontmatter


## 👩‍🚀 Release notes

Release notes are managed in `priv/changelog/` with version-based files. Release notes are available at `/changelog` and `/changelog/{version}` routes.

```
priv/changelog/
└── 0.1.0.md      # Release notes for version 0.1.0
```

Release notes use frontmatter for metadata:

```markdown
%{
  title: "Initial release",
  date: "2025-07-21"
}
---

# Changes

## New Features
- Feature 1 description
- Feature 2 description

## Bug Fixes
- Fix 1 description
- Fix 2 description

## Breaking Changes
- Breaking change description
```