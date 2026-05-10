# toolsup

Flutter project with Supabase email/password authentication.

## Supabase setup

1. Create a Supabase project at <https://supabase.com/dashboard>.
2. Open Authentication -> Providers.
3. Enable Email provider.
4. Copy Project URL and anon public key from Project Settings -> API.
5. Put them into `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
```

You can also pass the same values from VS Code through `.vscode/launch.json`
using `--dart-define`.

### Inventory data

Run `supabase/migrations/20260509_inventory_documents.sql` in Supabase SQL
Editor. It creates these tables:

- `inventory_documents` for document реквизиты.
- `fixed_assets` for the основное средство reference.
- `inventory_document_lines` for табличная часть and scanned availability.

The Flutter app reads inventory documents from these tables and writes QR/barcode
scan results back to `inventory_document_lines`.

## Run

```sh
flutter pub get
flutter run
```

For web:

```sh
flutter run -d chrome
```
# toolsup
