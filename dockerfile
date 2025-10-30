# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Create non-root user for build process
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# Copy csproj and restore dependencies
COPY ["YourApp.csproj", "./"]
RUN dotnet restore "YourApp.csproj"

# Copy everything else and build
COPY . .
RUN dotnet build "YourApp.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "YourApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Set proper ownership
COPY --from=publish --chown=appuser:appgroup /app/publish .

# Switch to non-root user
USER appuser

# Use non-privileged ports
EXPOSE 8080
EXPOSE 8081

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Security: Run as non-root, use read-only root filesystem where possible
ENTRYPOINT ["dotnet", "YourApp.dll"]