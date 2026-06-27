# Repository Guidelines

## Project Structure & Module Organization

This repository is currently empty. As code is added, keep the layout predictable and purpose-driven:

- `src/` for application source code.
- `tests/` for automated tests that mirror `src/` structure.
- `assets/` for static files such as icons, images, or packaged resources.
- `docs/` for design notes, setup details, and contributor-facing documentation.
- `scripts/` for repeatable local or CI automation.

Avoid placing generated build output in source directories. Prefer ignored directories such as `dist/`, `build/`, or tool-specific cache folders.

## Build, Test, and Development Commands

No build system is configured yet. When one is introduced, document the exact commands here and keep them runnable from the repository root. Recommended examples:

- `npm install` or equivalent: install project dependencies.
- `npm run dev`: start the local development workflow.
- `npm test`: run the automated test suite.
- `npm run build`: produce a distributable build.
- `npm run lint`: run formatting and static checks.

If this becomes a non-Node project, replace these examples with the project’s actual toolchain commands.

## Coding Style & Naming Conventions

Follow the conventions of the primary language and framework once selected. Keep names descriptive and consistent:

- Use `PascalCase` for classes, components, and types.
- Use `camelCase` for functions, variables, and object properties.
- Use `kebab-case` for command-line scripts and general file names unless the framework expects otherwise.

Add formatter and linter configuration before the codebase grows, and make formatting part of the standard check command.

## Testing Guidelines

Place tests in `tests/` or alongside source files using a clear suffix such as `.test.*` or `.spec.*`. Tests should cover core behavior, edge cases, and any platform-specific proxy switching logic added later. Keep test fixtures small and isolated.

## Commit & Pull Request Guidelines

No repository Git history is available yet, so use concise, imperative commit messages such as `Add proxy profile model` or `Fix menu state refresh`. Pull requests should include a summary, test results, linked issues when relevant, and screenshots or recordings for user-facing UI changes.

## Security & Configuration Tips

Do not commit secrets, personal proxy credentials, certificates, or machine-specific configuration. Store local settings in ignored environment files and provide sanitized examples such as `.env.example` when configuration is required.
