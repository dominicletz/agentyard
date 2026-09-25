FROM elixir:1.18-otp-28

ENV MIX_ENV=dev \
    LANG=C.UTF-8 \
    ERL_AFLAGS="-kernel shell_history enabled"

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock* ./
RUN mix deps.get

COPY assets/package.json ./assets/package.json
RUN cd assets && npm install

COPY . .
RUN mix compile && mix assets.deploy

EXPOSE 4000
CMD ["sh", "-c", "mix ecto.setup && mix phx.server"]
