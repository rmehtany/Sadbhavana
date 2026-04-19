# Google Drive Service Account Setup Guide

This guide explains how to set up automated Google Drive authentication using service accounts, eliminating the need for manual OAuth browser authentication.

## Prerequisites

- Google Cloud Platform account
- Access to Google Cloud Console
- Admin access to the Google Drive folders you want to access

## Step 1: Create a Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to **IAM & Admin** > **Service Accounts**
4. Click **Create Service Account**
5. Fill in the details:
   - **Name:** `sadbhavana-drive-access` (or your preferred name)
   - **Description:** `Service account for automated Google Drive access`
6. Click **Create and Continue**
7. Skip the optional steps (no roles needed at project level)
8. Click **Done**

## Step 2: Create and Download Service Account Key

1. Find your newly created service account in the list
2. Click on the service account email
3. Go to the **Keys** tab
4. Click **Add Key** > **Create new key**
5. Select **JSON** format
6. Click **Create**
7. The JSON key file will be downloaded automatically
8. **IMPORTANT:** Store this file securely - it contains sensitive credentials

## Step 3: Share Google Drive Folders with Service Account

The service account needs access to your Google Drive folders:

1. Open Google Drive
2. Find the folder you want to share (e.g., "SampleTreePhotos")
3. Right-click > **Share**
4. Add the service account email (looks like: `sadbhavana-drive-access@your-project.iam.gserviceaccount.com`)
5. Set permission to **Editor** or **Viewer** (depending on your needs)
6. Click **Share**

**Note:** You can find the service account email in the downloaded JSON file under `client_email`.

## Step 4: Configure Application

You have three options to configure the service account credentials:

### Option A: Using Environment Variable (Recommended for Development)

```bash
# Linux/Mac
export GOOGLE_SERVICE_ACCOUNT_JSON='<paste entire JSON content here>'

# Windows PowerShell
$env:GOOGLE_SERVICE_ACCOUNT_JSON='<paste entire JSON content here>'

# Windows CMD
set GOOGLE_SERVICE_ACCOUNT_JSON=<paste entire JSON content here>
```

Then run the setup:

```go
import "sadbhavana/tree-project/pkgs/auth"

err := auth.SetupGoogleServiceAccountFromEnv(ctx, queries)
if err != nil {
    log.Fatalf("Failed to setup service account: %v", err)
}
```

### Option B: Using JSON File

```go
import "sadbhavana/tree-project/pkgs/auth"

err := auth.SetupGoogleServiceAccountFromFile(ctx, queries, "path/to/service-account.json")
if err != nil {
    log.Fatalf("Failed to setup service account: %v", err)
}
```

### Option C: Using Database Migration (Recommended for Production)

1. Edit `pkgs/db/migrations/004_add_google_service_account.sql`
2. Replace the placeholder values with your actual service account details from the JSON file:
   - `client_email`: Copy from JSON file
   - `private_key`: Copy from JSON file (keep the `\n` characters)
   - `private_key_id`: Copy from JSON file
3. Run the migration:

```bash
psql -U your_user -d your_database -f pkgs/db/migrations/004_add_google_service_account.sql
```

## Step 5: Verify Setup

Run the test suite to verify everything works:

```bash
cd pkgs/file
go test -v -run TestNewUpdatedGoogleDriveFileStore_ServiceAccount
go test -v -run TestGoogleDriveServiceAccount_ListFiles
go test -v -run TestGoogleDriveServiceAccount_SearchFolder
```

Expected output:
```
=== RUN   TestNewUpdatedGoogleDriveFileStore_ServiceAccount
Successfully created Google Drive service with automated authentication
--- PASS: TestNewUpdatedGoogleDriveFileStore_ServiceAccount (0.50s)
```

## Step 6: Test the Photo Detection Endpoint

Start your server and test the endpoint:

```bash
# Start server
go run cmd/server/main.go

# In another terminal, call the endpoint
curl http://localhost:8080/api/photos/detect-and-send
```

You should see:
- ✅ Immediate response (no waiting for browser authentication)
- ✅ No prompts for OAuth URL
- ✅ No polling for code.json file
- ✅ Logs showing "Successfully created Google Drive service with automated authentication"

## Troubleshooting

### Error: "failed to get active token"

**Cause:** Service account credentials not configured in database.

**Solution:** Run one of the setup methods from Step 4.

### Error: "User not found" or "File not found"

**Cause:** Service account doesn't have access to the Google Drive folder.

**Solution:** Make sure you shared the folder with the service account email (Step 3).

### Error: "invalid_grant"

**Cause:** Private key is malformed or incorrect.

**Solution:** 
- Ensure the private key includes the full content with `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
- Make sure `\n` characters are preserved (not converted to actual newlines)
- Re-download the JSON key file if needed

### Token Refresh Issues

The application automatically refreshes tokens. If you see refresh errors:

1. Check database: `SELECT * FROM core.auth WHERE provider_name = 'google';`
2. Verify the `auth_config` has correct credentials
3. Check logs for specific error messages

## Security Best Practices

1. **Never commit service account keys to version control**
   - Add `*.json` to `.gitignore`
   - Use environment variables or secret management systems

2. **Limit service account permissions**
   - Only share specific folders, not entire Drive
   - Use "Viewer" permission if read-only access is sufficient

3. **Rotate keys periodically**
   - Create new keys every 90 days
   - Delete old keys after rotation

4. **Monitor service account usage**
   - Check Google Cloud Console for unusual activity
   - Enable audit logging

## Migration from Manual OAuth

If you were previously using manual OAuth:

1. Old files are now obsolete:
   - `credentials.json` - OAuth client credentials (no longer needed)
   - `token.json` - User OAuth tokens (no longer needed)
   - `code.json` - Authorization codes (no longer needed)

2. The `/oauth2/callback` endpoint is deprecated but kept for backward compatibility

3. All existing code using `NewUpdatedGoogleDriveFileStore` will automatically use the new service account authentication

## Additional Resources

- [Google Cloud Service Accounts Documentation](https://cloud.google.com/iam/docs/service-accounts)
- [Google Drive API Scopes](https://developers.google.com/drive/api/guides/api-specific-auth)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)
