# toolsup

Flutter project with Supabase email/password authentication.

## Supabase setup

1. Create a Supabase project at <https://supabase.com/dashboard>.
2. Open Authentication -> Providers.
3. Enable Email provider.
4. Copy Project URL and anon public key from Project Settings -> API.
5. Put them into `.env`:

You can also pass the same values from VS Code through `.vscode/launch.json`
using `--dart-define`.

### Email confirmation

Publish `web/email-confirmed.html` together with the web build or on any static
hosting. Then open Supabase Dashboard -> Authentication -> URL Configuration:

- Set Site URL to your public website URL instead of `localhost`.
- Add the exact confirmation page URL to Redirect URLs.

Use the same confirmation page URL in `SUPABASE_EMAIL_REDIRECT_URL`. If this is
not configured, Supabase falls back to Site URL, and a mobile phone can try to
open `localhost`.

### Inventory data

Run `supabase/migrations/20260509_inventory_documents.sql` in Supabase SQL
Editor. It creates these tables:

- `inventory_documents` for document реквизиты.
- `fixed_assets` for the основное средство reference.
- `inventory_document_lines` for табличная часть and scanned availability.

The Flutter app reads inventory documents from these tables and writes QR/barcode
scan results back to `inventory_document_lines`.

### Document workflow data

Run `supabase/migrations/20260518_document_workflow.sql` in Supabase SQL Editor.
It creates these tables:

- `document_workflow_documents` for workflow document headers.
- `document_workflow_route_steps` for business-process route steps.

Supported route actions are: согласование, подписание, рассмотрение,
ознакомление.

Run `supabase/migrations/20260519_app_user_profiles.sql` after the workflow
tables. It creates `app_user_profiles`, fills profiles from Supabase Auth user
metadata, and links workflow route executors to application users.

Run `supabase/migrations/20260519_user_profile_photos.sql` after that. It adds
profile photo fields and creates the private `user-profile-photos` Storage
bucket.

Run `supabase/migrations/20260519_organizations_and_user_org_fields.sql` after
that. It creates the `organizations` directory with BIN, short name, and full
name, then adds organization BIN and organization name fields to
`app_user_profiles`.

Run `supabase/migrations/20260519_link_profiles_to_organizations.sql` after
that. It links `app_user_profiles.organization_bin` to `organizations.bin`, so
the user profile organization is selected from the organization directory.

Run `supabase/migrations/20260519_document_workflow_attachments.sql` after that.
It creates:

- `document_workflow_attachments` for attached file metadata.
- `workflow-documents` Supabase Storage bucket for uploaded files.

# toolsup
