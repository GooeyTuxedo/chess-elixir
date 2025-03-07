FROM elixir:1.17-alpine

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Prepare working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=dev

# Install dependencies first (for better caching)
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy over the rest of the application code
COPY . .

# Install Node.js dependencies
# RUN cd assets && npm install

# Start the Phoenix app
CMD ["mix", "phx.server"]