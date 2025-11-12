# Codex Start Here

This repository hosts a Ruby on Rails 8 application with a React front-end that is bundled through esbuild. Use this file as the entry point when orienting Codex or any other automation around the project.

## Stack Overview
- **Ruby**: 3.3.5 (`.ruby-version`)
- **Rails**: 8.x (see `Gemfile`)
- **JavaScript runtime**: Node 22.5.0 (`.node-version`)
- **Package managers**: Bundler + Yarn
- **Database**: MySQL (see `config/database.yml`)
- **Processes**: Foreman via `bin/dev` / `Procfile.dev`

## UI Guidelines
- **Icons**: Lucide is loaded globally via CDN (`https://unpkg.com/lucide@latest`). Use `<i data-lucide="icon-name"></i>` in views/components; icons are auto-initialized on each `turbo:load`.
- **Authenticated layout**: Logged-in screens render through `layouts/authenticated` which already includes the sidebar (`shared/_sidebar`). New signed-in views only need to supply their main content; they shouldn’t duplicate sidebar markup.

## Documents
- spec is written on `README.md`
- todo is written on `TODO.md`
