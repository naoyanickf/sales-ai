# TODO

## Streaming chat (/chats/new)
- [ ] Install the dependencies required by the streaming-chat guide: add `ruby-openai` (>=7) and `turbo-rails` to the `Gemfile`, pull `@hotwired/turbo-rails` into the esbuild pipeline via `package.json`/`app/javascript/application.js`, and bundle/yarn so Turbo Streams + Hotwire helpers are available.
- [ ] Expose the OpenAI credential in configuration by adding `OPENAI_API_KEY` (or `OPENAI_ACCESS_TOKEN`) to `.env.example`, documenting it in `README.md`, and wiring Rails to read it (initializer or credentials).
- [ ] Design and migrate the conversation tables described in `README.md` (chat/conversation + message): create a `chats` table tied to `user`, `workspace`, `product`, and optional `sales_expert`, plus a `messages` table with `role` enum, `content:text`, and `response_number` for streaming placeholders; add indexes + FK constraints.
- [ ] Implement `Chat` and `Message` models with the required associations/validations, `enum role`, scope for ordering, `Message.for_openai` helper, and Turbo broadcast callbacks so message updates appear over Action Cable.
- [ ] Add controllers and routes: introduce `ChatsController` (auth + workspace guard) with `/chats/new` rendering the chat UI, and a nested `MessagesController#create` that saves user prompts, handles Turbo Stream responses, and enqueues the AI job on success; update `config/routes.rb` accordingly.
- [ ] Build the background streaming layer: create a SolidQueue-backed job (e.g., `AiResponseJob`) plus a service object that calls `OpenAI::Client` with `stream:` callbacks, creates assistant placeholder messages, updates them per chunk, and handles error/timeout cleanup.
- [ ] Create the chat UI views/partials under `app/views/chats` and `app/views/messages`: Turbo-enabled message list with `turbo_stream_from`, Bootstrap-styled message bubbles, Turbo Frame form, and `create.turbo_stream.erb` templates mirroring the guide but using this app’s design system.
- [ ] Enhance the frontend behavior so the chat container auto-scrolls when new Turbo Stream updates land and the send button disables during streaming; verify Turbo JS + Action Cable connect correctly after importing `turbo-rails`.
- [ ] Surface the feature entry point by adding a sidebar/nav link to `/chats/new` and ensure development tooling (`Procfile.dev` / `bin/dev`) launches a SolidQueue worker so streaming jobs execute locally.
- [ ] Add automated tests (models, controller Turbo responses, job/service with mocked OpenAI stream) to lock in the chat behavior.
