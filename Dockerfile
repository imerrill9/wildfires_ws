# Use the official Elixir image as base (Elixir 1.18.4 on OTP 28)
FROM elixir:1.18.4-otp-28

# Set working directory
WORKDIR /app

# Install hex package manager and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get

# Copy application code
COPY . .

# Compile the application
RUN mix compile

# Expose port
EXPOSE 4000

# Set environment variables
ENV PHX_SERVER=true
ENV PORT=4000

# Start the application
CMD ["mix", "phx.server"]
