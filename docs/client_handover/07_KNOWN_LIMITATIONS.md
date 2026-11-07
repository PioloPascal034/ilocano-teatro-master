# Known Limitations

- Android real-device testing was not possible in the inspected environment; the connected-device check did not find a phone and `adb` was unavailable on PATH.
- The current Android release Gradle configuration uses the debug signing configuration. APK/AAB artifacts must not be treated as production-signed until a protected release keystore is configured and verified.
- Published learning content is not yet sufficient for an unrestricted client demonstration: several modules were empty in the prior evidence and the visible quiz content was test-like.
- No approved published Story Vault story remained after isolated QA testing in the prior evidence environment.
- Lesson illustrations are not implemented in the current lesson schema/editor. Story covers, chapter illustrations, and profile photos have separate media paths.
- Teacher accounts and assignments require owner/administrator provisioning; the app does not provide a general assignment-management editor.
- UI completion of every lesson, quiz, story, and chapter publish/unpublish action was not verified live.
- UI file chooser upload and all live avatar replacement/image-rendering combinations remain partially verified.
- Live review decision submission from the browser was not performed, although repository review, feedback, revision, and approval workflows passed.
- An unassigned-teacher and second-student RLS isolation matrix remains to be tested.
- The AI Writing Coach is excluded from this release and is not implemented/documented as an available feature.
- No public deployment, Supabase policy change, Edge Function deployment, Google Play upload, or record deletion was performed.

## Client-provided inputs still required

- Approved curriculum and cultural story content.
- Production teacher account list and assignment policy.
- Release signing ownership, keystore, and secure CI/Play App Signing setup.
- Approved Web host and DNS/HTTPS configuration.
- Privacy policy, Data Safety, content rating, and other release declarations.
