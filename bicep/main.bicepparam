using './main.bicep'

// Demo values only — not real credentials.
// In a real deployment, pass these at deploy time
// (e.g. `--parameters apiKey=$(read -s)`) so they
// never get committed to the repo.

param databaseConnection = 'Server=example.database.windows.net;Database=AppDb;User=appuser'
param apiKey             = 'demo-api-key-not-a-real-secret'
param appSecret          = 'demo-app-secret-not-a-real-secret'
