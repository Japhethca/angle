FROM elixir:1.17.3-otp-27-alpine as builder

# Install build dependencies
RUN apk add --no-cache build-base git

# Set up the application directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force &&     mix local.rebar --force

# Copy over the application code
COPY . .

# Fetch dependencies
RUN mix deps.get

# Build the application
RUN mix release

# Create a smaller production image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache bash openssl ncurses-libs

# Set up the application directory
WORKDIR /app

# Copy the built release from the builder stage
COPY --from=builder /app/_build/prod/rel/angle .

# Expose the application port
EXPOSE 4000

# Define the entrypoint
ENTRYPOINT ["/app/bin/server"]

