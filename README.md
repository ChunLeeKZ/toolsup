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

## Run

```sh
flutter pub get
flutter run
```

For web:

```sh
flutter run -d chrome
```
