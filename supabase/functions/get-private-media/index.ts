import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

type MediaType = "avatar" | "story_cover" | "chapter_illustration";

type ResolvedMedia = {
  bucket: string;
  path: string;
  recordId: string;
  expectedExtension: string;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ALLOWED_EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp"]);
const MIME_BY_SIGNATURE = new Map<string, string>([
  ["jpeg", "image/jpeg"],
  ["png", "image/png"],
  ["webp", "image/webp"],
]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  Vary: "Origin, Authorization",
};

function jsonError(status: number, code: string): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: {
      ...corsHeaders,
      "Cache-Control": "no-store",
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function defaultKeyFromJson(value: string | undefined): string | undefined {
  if (!value) return undefined;
  try {
    const keys = JSON.parse(value) as Record<string, unknown>;
    return typeof keys.default === "string" ? keys.default : undefined;
  } catch {
    return undefined;
  }
}

function configuredKey(
  singleName: string,
  pluralName: string,
  legacyName: string,
): string | undefined {
  return Deno.env.get(singleName) ??
    defaultKeyFromJson(Deno.env.get(pluralName)) ??
    Deno.env.get(legacyName);
}

function resolveApiConfig(): {
  url: string;
  publishableKey: string;
  secretKey: string;
  legacySecretKey: boolean;
} | null {
  const url = Deno.env.get("SUPABASE_URL");
  const publishableKey = configuredKey(
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_ANON_KEY",
  );
  const secretKey = configuredKey(
    "SUPABASE_SECRET_KEY",
    "SUPABASE_SECRET_KEYS",
    "SUPABASE_SERVICE_ROLE_KEY",
  );
  if (!url || !publishableKey || !secretKey) return null;
  return {
    url: url.replace(/\/$/, ""),
    publishableKey,
    secretKey,
    legacySecretKey: secretKey.startsWith("eyJ"),
  };
}

function isValidRequest(value: unknown): value is {
  type: MediaType;
  recordId: string;
} {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const body = value as Record<string, unknown>;
  return Object.keys(body).length === 2 &&
    Object.hasOwn(body, "type") &&
    Object.hasOwn(body, "recordId") &&
    (body.type === "avatar" || body.type === "story_cover" ||
      body.type === "chapter_illustration") &&
    typeof body.recordId === "string" && UUID_PATTERN.test(body.recordId);
}

function validStoredPath(
  type: MediaType,
  recordId: string,
  parentStoryId: string | null,
  path: string | null,
): path is string {
  if (!path || path.includes("\\") || path.startsWith("/")) return false;
  const parts = path.split("/");
  if (parts.some((part) => part.length === 0 || part === "." || part === "..")) {
    return false;
  }
  const extension = parts.at(-1)?.split(".").at(-1)?.toLowerCase();
  if (!extension || !ALLOWED_EXTENSIONS.has(extension)) return false;

  if (type === "avatar") {
    return parts.length === 2 && parts[0] === recordId;
  }
  if (type === "story_cover") {
    return parts.length === 3 && parts[0] === recordId && parts[1] === "cover";
  }
  return parts.length === 4 && parts[0] === parentStoryId &&
    parts[1] === "chapters" && parts[2] === recordId;
}

async function isCurriculumEditor(client: SupabaseClient): Promise<boolean> {
  const { data, error } = await client.rpc("is_curriculum_editor");
  return !error && data === true;
}

async function canReviewStudent(
  client: SupabaseClient,
  studentId: string,
): Promise<boolean> {
  const { data, error } = await client.rpc("can_review", {
    target_student: studentId,
  });
  return !error && data === true;
}

async function resolveAvatar(
  client: SupabaseClient,
  userId: string,
  recordId: string,
): Promise<ResolvedMedia | null> {
  const { data: profile, error } = await client
    .from("profiles")
    .select("id, role, avatar_storage_path")
    .eq("id", recordId)
    .maybeSingle();
  if (error || !profile) return null;

  const isOwner = profile.id === userId;
  if (!isOwner && (profile.role !== "student" ||
    !await canReviewStudent(client, recordId))) {
    return null;
  }

  const path = profile.avatar_storage_path as string | null;
  if (!validStoredPath("avatar", recordId, null, path)) return null;
  return {
    bucket: "ilocano-profile-avatars",
    path,
    recordId,
    expectedExtension: path.split("/").at(-1)!.split(".").at(-1)!.toLowerCase(),
  };
}

async function resolveStoryCover(
  client: SupabaseClient,
  recordId: string,
): Promise<ResolvedMedia | null> {
  const { data: story, error } = await client
    .from("cultural_stories")
    .select("story_id, is_published, cover_storage_path")
    .eq("story_id", recordId)
    .maybeSingle();
  if (error || !story) return null;
  if (story.is_published !== true && !await isCurriculumEditor(client)) {
    return null;
  }

  const path = story.cover_storage_path as string | null;
  if (!validStoredPath("story_cover", recordId, null, path)) return null;
  return {
    bucket: "ilocano-story-media",
    path,
    recordId,
    expectedExtension: path.split("/").at(-1)!.split(".").at(-1)!.toLowerCase(),
  };
}

async function resolveChapterIllustration(
  client: SupabaseClient,
  recordId: string,
): Promise<ResolvedMedia | null> {
  const { data: chapter, error } = await client
    .from("story_chapters")
    .select("chapter_id, story_id, is_published, illustration_storage_path")
    .eq("chapter_id", recordId)
    .maybeSingle();
  if (error || !chapter) return null;

  const { data: story, error: storyError } = await client
    .from("cultural_stories")
    .select("story_id, is_published")
    .eq("story_id", chapter.story_id)
    .maybeSingle();
  if (storyError || !story) return null;

  const isPublished = chapter.is_published === true &&
    story.is_published === true;
  if (!isPublished && !await isCurriculumEditor(client)) return null;

  const storyId = chapter.story_id as string;
  const path = chapter.illustration_storage_path as string | null;
  if (!validStoredPath("chapter_illustration", recordId, storyId, path)) {
    return null;
  }
  return {
    bucket: "ilocano-story-media",
    path,
    recordId,
    expectedExtension: path.split("/").at(-1)!.split(".").at(-1)!.toLowerCase(),
  };
}

function sniffImageMime(bytes: Uint8Array): string | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
    bytes[2] === 0xff) return MIME_BY_SIGNATURE.get("jpeg")!;
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
    bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d &&
    bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) {
    return MIME_BY_SIGNATURE.get("png")!;
  }
  if (bytes.length >= 12 &&
    String.fromCharCode(...bytes.subarray(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP") {
    return MIME_BY_SIGNATURE.get("webp")!;
  }
  return null;
}

function pathForStorageUrl(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((part) => part.toString(16).padStart(2, "0"))
    .join("");
}

async function handleRequest(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") return jsonError(405, "method_not_allowed");

  const authorization = request.headers.get("Authorization");
  const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!bearer) return jsonError(401, "unauthenticated");

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError(400, "invalid_request");
  }
  if (!isValidRequest(body)) return jsonError(400, "invalid_request");

  const config = resolveApiConfig();
  if (!config) return jsonError(503, "media_service_unavailable");

  const userClient = createClient(config.url, config.publishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
    global: { headers: { Authorization: "Bearer " + bearer } },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser(bearer);
  if (authError || !authData.user) return jsonError(401, "unauthenticated");

  let media: ResolvedMedia | null;
  if (body.type === "avatar") {
    media = await resolveAvatar(userClient, authData.user.id, body.recordId);
  } else if (body.type === "story_cover") {
    media = await resolveStoryCover(userClient, body.recordId);
  } else {
    media = await resolveChapterIllustration(userClient, body.recordId);
  }
  if (!media) return jsonError(404, "media_not_found");

  const storageResponse = await fetch(
    config.url + "/storage/v1/object/" + media.bucket + "/" +
      pathForStorageUrl(media.path),
    {
      method: "GET",
      headers: {
        apikey: config.secretKey,
        ...(config.legacySecretKey
          ? { Authorization: "Bearer " + config.secretKey }
          : {}),
      },
      redirect: "error",
    },
  );
  if (!storageResponse.ok) return jsonError(404, "media_not_found");
  const contentLength = Number(storageResponse.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > 5 * 1024 * 1024) {
    return jsonError(413, "media_too_large");
  }

  const bytes = new Uint8Array(await storageResponse.arrayBuffer());
  if (bytes.length === 0) return jsonError(404, "media_not_found");

  const contentType = sniffImageMime(bytes);
  const extensionMatches = media.expectedExtension === "jpg" ||
      media.expectedExtension === "jpeg"
    ? contentType === "image/jpeg"
    : media.expectedExtension === "png"
    ? contentType === "image/png"
    : contentType === "image/webp";
  if (!contentType || !extensionMatches) {
    return jsonError(415, "unsupported_media");
  }

  const etag = '"' + await sha256(bytes) + '"';
  const headers = {
    ...corsHeaders,
    "Cache-Control": "private, max-age=60, must-revalidate",
    "Content-Length": String(bytes.length),
    "Content-Disposition": "inline",
    "Content-Type": contentType,
    ETag: etag,
    "X-Content-Type-Options": "nosniff",
  };
  if (request.headers.get("If-None-Match") === etag) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(bytes, { status: 200, headers });
}

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch {
    return jsonError(503, "media_service_unavailable");
  }
});
