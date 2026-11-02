# get-private-media

This function returns private avatar and Story Vault image bytes after resolving
the requested record through the caller's authenticated, RLS-scoped database
client. Its request body is restricted to:

```json
{
  "type": "avatar | story_cover | chapter_illustration",
  "recordId": "<UUID>"
}
```

It does not accept a bucket or object path. It verifies the caller with Auth,
reads the saved path under the caller's database policies, applies the existing
`can_review(uuid)` or `is_curriculum_editor()` checks where required, validates
the expected bucket path shape, and only then retrieves bytes using the
server-side Storage key.

Responses are JPEG, PNG, or WebP bytes with a matching `Content-Type`,
`X-Content-Type-Options: nosniff`, and private one-minute caching. Missing or
unauthorized records return the same `404 media_not_found` response. Function
errors contain no database details or object paths.

## Deployment

The Supabase CLI is not installed in the current development environment.
Supabase supports deploying functions from the Dashboard or with the CLI.
Deployment has not been performed.

### Dashboard fallback

1. Open **Edge Functions** in the project Dashboard and create
   `get-private-media`.
2. Paste the contents of `index.ts` into the function editor.
3. Keep JWT verification enabled (the checked-in
   `supabase/config.toml` also sets `verify_jwt = true`).
4. Deploy only after explicit approval.

The hosted function reads Supabase's server-provided URL, publishable key, and
secret/service key environment variables. Do not add any secret key to Flutter,
the web build, this repository, or client build defines.

The Dashboard editor is a supported way to deploy without the CLI, but Supabase
notes that edits made there are not version-controlled and cannot be rolled
back from the editor. Keep the checked-in source as the reviewable copy.

### CLI alternative

The CLI is the version-controlled deployment path. Install it using an official
supported method, authenticate, link this project, then deploy only this
function:

```sh
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase functions deploy get-private-media --project-ref <project-ref>
```

Review the linked project and function source before running the deploy command.
Do not use `supabase functions deploy` without a function name in this repo.

## Manual release validation

After deployment, use real authenticated sessions and verify:

- A student can retrieve and render only their own avatar.
- An assigned teacher can retrieve and render that student's avatar.
- A published story cover and a published chapter illustration return image
  bytes and render in Android and Flutter Web.
- A curriculum editor can view unpublished media only while the existing
  `is_curriculum_editor()` function authorizes that user.
- An unrelated student cannot retrieve another student's avatar; unpublished
  media is rejected for non-editors.
- Requests with no valid user session, unsupported types, malformed UUIDs, or
  extra fields are rejected.
- Missing image references display the app's existing fallback.

Record only HTTP status, safe error code, content type, byte count, and visual
render outcome. Never record request credentials or Authorization headers.
