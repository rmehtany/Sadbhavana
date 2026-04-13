-- +goose up
-- Migration: Add Google Service Account Authentication
-- This migration sets up automated Google Drive authentication using service accounts
-- 
-- IMPORTANT: Before running this migration, you must:
-- 1. Create a service account in Google Cloud Console
-- 2. Download the JSON key file
-- 3. Share your Google Drive folders with the service account email
-- 4. Replace the placeholder values below with actual credentials
--
-- Security Note: For production, consider using environment variables instead
-- of storing credentials directly in this file. Use the SetupGoogleServiceAccountFromEnv
-- function in pkgs/auth/service_account_setup.go

-- Insert Google service account credentials
-- Replace the placeholder values with your actual service account details
INSERT INTO core.Authentication (
    provider_name,
    auth_config,
    active_token
) VALUES (
    'google',
    '{
        "auth_type": "client_credentials",
        "client_credentials": {
            "provider_type": "google",
            "client_email": "drivegeminibot@sadbhavnatest1.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC76IiwheLMb1SB\n8TYcD6827+7PwNpvgFQ8DRFtNw7ggvFCIdo3xiJxZmqb+xzk7E2C8DMYORyubmJj\nAo8mEYKPAV3Ghk5Y4Hx+nQhG/YOuHPgyfueNfUnrUZ/ZYVsP3M+IZF102jlaFTqW\npcDLYhNK2XeO/45Qpkcl+cIuTNmihJk9jdmnFXAJOCqaX173z6EAED3p5IgeN2LV\n3FE1uqTTvVzc2mf4yoSL9QSFtFiLw7GfZy/XxaMw5Ab8CIuzhnbKKM/0j0H2XuQ0\nxO5yDMKpCIFpfySPq0JCZjgI5mtQubPjrXKBEYaItn8VV963j1WCPvFXkjsQwIo0\nT7SImxR1AgMBAAECggEAK/i2Q9iQwhYrSF0RtG9XKRvsXmFavEzjaUoFkfEYYiFC\nI5+YWQTcenzk5atVj5xcZw+eZUS4GXlrPJAUv2vJiX1gXFyBaPrfJyHIFhStA8lz\nqx1XQhzXd2GablwB2yxoxBn4ZKfMU/AzzZzsCKvip9lLyQK0YtsGOzS+4+bH5ueJ\njPjcYSbEXhUrCaUPwWXVUYNcd5AfO9pyBSYvlqmn1G6Y2g9pJZ1I6wtDlYQ0UkMk\n6WG57dUmj68OORTvZAGAHhJz3Z71pjJNQq3HJXcAp/GK8TvRlJGuzmFrXnEJkQRl\nDARFsAYJgkj+1TcISnT5dKPS/etPDtnevqGkzpAXAQKBgQDvCiKXCSB6dSYKMGxY\ninm9/CbVd3+l1GdCLAFMqJt3oM1AwMGejPlu1UYmClYZx9mzCyeYGK9NUrREvtaL\ndR0eQ8FyvJxmsQXMQNpInY7aBT1SHQ/zg9h3aPM6tQQiGa1wTUSwPrdvtBhnV12L\nB7vG1TedipkF0b8fxEoZNg0XDQKBgQDJPalVrhAcF1EjxbDmAIn9VX6brZwwvqJb\nsiG3SHXe13zojTPXoFMt4RRiRlsCbg4yt+1Gj22ZOdYNsB9MFHbl8/+0BQWhoNM6\nDnDTtuBcTgXlIuxoMUtTD6nYmx8uVrs8gMDeOzZGO4lgBKg9fnYlaviCpRKhpWqv\n3v0i3TkZCQKBgCiUueaWQBNKDBkyu1IUwDJGunkG/n6yno0XV2kiPrKCdBYII1a9\nbCMqxevzWUarLQQ+YoxptGkWH1CEbXvjd/wJWLAX4R119BwG7ofhZ70PoqdsE6ct\nvPQYtyJCVN9NKKqmE4EwRIgMNRBmPpU5zOEmlXiDbRMV1rKX6lR5XqOJAoGAZcq4\n4sv+/haVRmDzEARpyCj8t8ZjYQysl3FNOKaAaM3bMs5p0MIaEPTvGJ653krJB8Kd\nVLmsGHt22MmjqxoW4k4/o1F+/biZ3536WD0C0+3rcXHu3u1ASq17nkMozIm2f+4o\noMCWvYPUAyuX5jMXk+m99meFOxqvEnLa3E3GWfECgYB1Zv6BYcpV0uBETF9WHbOR\n952fPVjRzIwYdgRG3m/rP24+OrMx9BHAVWJsKVdxRtruY/YbKOXWFYarMoZ9+XoX\nBlGKuNvJvPDU4j4Z6NprR56Dfv7cuDUI0PfdZ8lLCjzpW6EO8ed0OLS35rxJ3Ira\nV8F8+Q04Tz91DvQTvsVLQg==\n-----END PRIVATE KEY-----\n",
            "private_key_id": "9c33b4b6ead1f531276012d36c4044c6831d5878",
            "scopes": ["https://www.googleapis.com/auth/drive"]
        }
    }'::jsonb,
    NULL  -- Token will be auto-generated on first use
) ON CONFLICT (provider_name) DO UPDATE
SET auth_config = EXCLUDED.auth_config;

-- Verify the insertion
SELECT 
    provider_name,
    auth_config->>'auth_type' as auth_type,
    auth_config->'client_credentials'->>'client_email' as service_account_email
FROM core.Authentication
WHERE provider_name = 'google';
