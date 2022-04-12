FROM elixir:1.13.2
WORKDIR /app
COPY . .
RUN mix local.hex --force
RUN mix deps.get
CMD mix run --no-halt