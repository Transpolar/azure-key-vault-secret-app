# Azure Key Vault + Managed Identity Demo

A proof-of-concept that deploys an ASP.NET Core 9 web app on Azure App Service which reads its secrets from Azure Key Vault using a **System-Assigned Managed Identity**. No credentials are stored in code, config, or environment variables — the app authenticates to Key Vault using only its identity.

> **Important — this is a proof of concept.**
> The deployed page prints secret values directly to the browser. That is intentional for this demo: it visually confirms that the app retrieved the secrets through Managed Identity rather than from local config. **Never do this in a real application.** Secrets should be consumed inside the app (e.g. used to open a database connection) and never rendered to the UI, written to logs, or returned in HTTP responses.

## What this is for

The pattern this repo demonstrates — secrets in Key Vault, accessed from a Web App via Managed Identity, with RBAC controlling who can read what — is the standard way to handle credentials in modern Azure workloads. It removes connection strings and API keys from `appsettings.json`, environment variables, and CI/CD secrets.

I built it because the publicly available walkthroughs for this pattern were out of date: older .NET runtimes, access-policy-based authorization instead of the RBAC model Microsoft now recommends, missing role-propagation waits, and no working end-to-end script. The full flow is captured here as a Bicep template — declarative, idempotent, and close to how this would actually be built in a real project.

## What I learned building this

A few things that turned out to be more involved than the tutorials suggested:

- **Role assignments are eventually consistent.** When you enable a system-assigned managed identity on an App Service, the corresponding service principal in Entra ID can take 30–60 seconds to become visible to RBAC operations. The Bicep version avoids this problem entirely because ARM sequences the identity creation and role assignment in one transaction — something that's painful to get right in imperative scripts.
- **RBAC vs access policies.** Key Vault has two authorization modes. Access policies are the older, vault-local model; RBAC uses Azure-wide role assignments and is the current recommendation. This demo uses RBAC throughout (`Key Vault Secrets Officer` for the deploying user, `Key Vault Secrets User` for the Web App).
- **`DefaultAzureCredential` is doing more than it looks.** It transparently tries multiple credential sources — environment variables, managed identity, Azure CLI login, Visual Studio — so the same `Program.cs` works locally with `az login` and in production with the managed identity. No code change between dev and prod.
- **Key Vault as a configuration provider.** Once registered with `builder.Configuration.AddAzureKeyVault(...)`, secrets are accessed through the standard `IConfiguration` API. The application code doesn't know or care that the value came from Key Vault rather than `appsettings.json` — which means swapping in Key Vault is a deployment concern, not a code change.
- **Declarative wins for anything past a demo.** The Bicep template is shorter than the equivalent CLI script, idempotent (re-running it converges to the same state), and handles dependency ordering automatically.

## Architecture

```
Browser
  │
  ▼
App Service (ASP.NET Core 9)
  │  uses System-Assigned Managed Identity
  ▼
Azure Key Vault (RBAC)
  ├── DatabaseConnection
  ├── ApiKey
  └── AppSecret
```

The Web App is configured with a single environment variable, `KeyVaultName`. On startup the app constructs a `DefaultAzureCredential` and registers Key Vault as a configuration provider, so secrets are then accessed through the standard `IConfiguration` interface — exactly the same code you'd write against `appsettings.json`.

The infrastructure lives in [`bicep/`](./bicep/): `main.bicep` is the template, `main.bicepparam` holds the parameter values, and `deploy.sh` is a thin wrapper that runs `az deployment group create` and publishes the app code.

## Requirements

- An Azure subscription where you can create resource groups, role assignments, and App Services
- Azure CLI (`az`) — log in once with `az login`
- .NET 9 SDK
- `zip` and `jq`

## Deploy from GitHub

The repo lives at [github.com/Transpolar/azure-key-vault-secret-app](https://github.com/Transpolar/azure-key-vault-secret-app).

```bash
git clone https://github.com/Transpolar/azure-key-vault-secret-app.git
cd azure-key-vault-secret-app/bicep
chmod +x deploy.sh
./deploy.sh
```

The script prints an App URL when it finishes. Give the App Service ~60 seconds to cold-start, then open the URL.

## Cleanup

```bash
az group delete --name keyvault-secret-app-rg --yes --no-wait
```

This removes the resource group and everything inside it. The Key Vault is soft-delete-enabled by default, so its name remains reserved for 90 days — if you want to redeploy with the same name within that window, run `az keyvault purge --name <name>`.

## Notes

- The secret values committed in this repo are demo placeholders, not real credentials. For a real deployment, pass secrets at deploy time (e.g. `--parameters apiKey=$(read -s)`) rather than committing them, and consider sourcing them from a separate Key Vault that holds bootstrap secrets.
- The default region is `norwayeast`. Change `LOCATION` at the top of `deploy.sh` (or the `location` parameter in `main.bicepparam`) if you want a different region.
- The Web App SKU is `B1` (Basic) — cheap to run but slow to cold-start. Change `appServicePlanSku` in `main.bicep` if you want something faster.
