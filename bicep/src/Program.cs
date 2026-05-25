using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);

var keyVaultName = Environment.GetEnvironmentVariable("KeyVaultName");

if (!string.IsNullOrEmpty(keyVaultName))
{
    var keyVaultUri = new Uri($"https://{keyVaultName}.vault.azure.net/");
    builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential());
}

var app = builder.Build();

app.MapGet("/", () =>
{
    var kvName     = Environment.GetEnvironmentVariable("KeyVaultName");
    var dbConn     = app.Configuration["DatabaseConnection"];
    var apiKey     = app.Configuration["ApiKey"];
    var appSecret  = app.Configuration["AppSecret"];

    string Row(string name, string? value) =>
        $@"<div class='row'>
             <div class='label'>{name}</div>
             <div class='value {(string.IsNullOrEmpty(value) ? "empty" : "")}'>{(string.IsNullOrEmpty(value) ? "Not found" : value)}</div>
           </div>";

    var html = $@"<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>Azure Key Vault Secret App</title>
  <link rel='preconnect' href='https://fonts.googleapis.com'>
  <link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>
  <link href='https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap' rel='stylesheet'>
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: 'Inter', sans-serif;
      background: #f4f4f4;
      color: #1a1a1a;
      min-height: 100vh;
      display: flex;
      align-items: flex-start;
      justify-content: center;
      padding: 48px 16px;
    }}
    .card {{
      background: #fff;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      padding: 40px;
      width: 100%;
      max-width: 720px;
    }}
    .header {{
      border-bottom: 1px solid #e5e5e5;
      padding-bottom: 24px;
      margin-bottom: 28px;
    }}
    h1 {{
      font-size: 1.5rem;
      font-weight: 600;
      letter-spacing: -0.02em;
    }}
    .badge {{
      display: inline-block;
      margin-top: 10px;
      background: #ecfdf5;
      color: #16a34a;
      font-size: 0.75rem;
      font-weight: 500;
      padding: 4px 10px;
      border-radius: 999px;
    }}
    .vault-info {{
      margin-bottom: 28px;
      font-size: 0.875rem;
      color: #6b7280;
    }}
    .vault-info span {{
      font-weight: 500;
      color: #374151;
    }}
    .secrets-title {{
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #9ca3af;
      margin-bottom: 12px;
    }}
    .row {{
      display: flex;
      align-items: flex-start;
      gap: 16px;
      padding: 14px 0;
      border-bottom: 1px solid #f3f4f6;
    }}
    .row:last-child {{ border-bottom: none; }}
    .label {{
      font-size: 0.875rem;
      font-weight: 500;
      color: #374151;
      min-width: 180px;
    }}
    .value {{
      font-family: 'Courier New', monospace;
      font-size: 0.8125rem;
      color: #0369a1;
      word-break: break-all;
      flex: 1;
    }}
    .value.empty {{ color: #ef4444; font-style: italic; font-family: 'Inter', sans-serif; }}
    .note {{
      margin-top: 28px;
      padding: 14px 16px;
      background: #f9fafb;
      border-radius: 8px;
      font-size: 0.8125rem;
      color: #6b7280;
      line-height: 1.6;
    }}
    .note strong {{ color: #374151; }}
  </style>
</head>
<body>
  <div class='card'>
    <div class='header'>
      <h1>Azure Key Vault Secret App</h1>
      <div class='badge'>Connected to Key Vault</div>
    </div>
    <div class='vault-info'>Key Vault: <span>{kvName ?? "Not configured"}</span></div>
    <div class='secrets-title'>Secrets</div>
    {Row("DatabaseConnection", dbConn)}
    {Row("ApiKey", apiKey)}
    {Row("AppSecret", appSecret)}
    <div class='note'>
      <strong>Note:</strong> These values are retrieved securely from Azure Key Vault using Managed Identity.
      No credentials are stored in code or configuration files.
    </div>
  </div>
</body>
</html>";

    return Results.Content(html, "text/html");
});

app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

app.Run();
