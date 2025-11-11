# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Front-end (React)

- React and ReactDOM are installed via Yarn. Run `yarn install` after pulling changes.
- React components for prototyping live under `app/javascript/dev/react`. A sample `HelloWorld` component renders on the home page (`/`).
- Compile assets with `yarn build` or run `bin/dev` to keep esbuild watching for changes.

## Authentication

- Devise with `confirmable` is enabled for `User`. Run `bin/rails db:migrate` after pulling and make sure to confirm the account via email before logging in.
- In development confirmation emails are delivered through `letter_opener_web`; start the server and visit `/letter_opener` to open the confirmation link.
