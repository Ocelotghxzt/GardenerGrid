const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();

// Override these defaults with AI_ENDPOINT and AI_MODEL environment variables
// when GardenerGrid needs to target a different upstream provider or model.
const DEFAULT_ENDPOINT = "https://api.deepseek.com/chat/completions";
const DEFAULT_MODEL = "deepseek-chat";
const MAX_HISTORY_MESSAGES = 16;
const MAX_TEXT_LENGTH = 4000;
const MAX_LEARNED_NOTES = 20;
const MAX_VERIFIED_INSIGHTS = 24;

exports.chatAssistant = onCall(
  {
    cors: true,
    memory: "512MiB",
    secrets: ["AI_API_KEY"],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to GardenerGrid to use cloud AI.",
      );
    }

    const apiKey = process.env.AI_API_KEY;
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "Set the AI_API_KEY Functions secret before deploying cloud AI.",
      );
    }

    const endpoint = readString(process.env.AI_ENDPOINT, DEFAULT_ENDPOINT);
    const model = readString(process.env.AI_MODEL, DEFAULT_MODEL);
    const userMessage = clipText(request.data?.userMessage);

    if (!userMessage) {
      throw new HttpsError("invalid-argument", "userMessage is required.");
    }

    const messages = [
      {
        role: "system",
        content: buildSystemPrompt({
          soilContext: normalizeSoilContext(request.data?.soilContext),
          learnedContext: normalizeStringList(
            request.data?.learnedContext,
            MAX_LEARNED_NOTES,
          ),
          verifiedInsights: normalizeStringList(
            request.data?.verifiedInsights,
            MAX_VERIFIED_INSIGHTS,
          ),
        }),
      },
      ...normalizeHistory(request.data?.history),
      {role: "user", content: userMessage},
    ];

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: ["Bearer", apiKey].join(" "),
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: 1024,
          temperature: 0.7,
        }),
        signal: controller.signal,
      });

      const responseText = await response.text();
      if (!response.ok) {
        if (response.status === 401) {
          throw new HttpsError(
            "internal",
            "The server-side AI credential was rejected by the upstream provider.",
          );
        }
        if (response.status === 429) {
          throw new HttpsError(
            "resource-exhausted",
            "The cloud assistant is rate limited right now.",
          );
        }
        throw new HttpsError(
          "unavailable",
          `The AI provider returned ${response.status}.`,
        );
      }

      let payload;
      try {
        payload = JSON.parse(responseText);
      } catch (_) {
        throw new HttpsError(
          "internal",
          "The AI provider returned invalid JSON.",
        );
      }

      const content = payload?.choices?.[0]?.message?.content;
      if (typeof content !== "string" || !content.trim()) {
        throw new HttpsError(
          "internal",
          "The AI provider returned an empty response.",
        );
      }

      return {
        content: content.trim(),
        model,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error?.name === "AbortError") {
        throw new HttpsError(
          "deadline-exceeded",
          "The cloud assistant timed out.",
        );
      }

      console.error("chatAssistant failed", error);
      throw new HttpsError(
        "unavailable",
        "The cloud assistant could not be reached.",
      );
    } finally {
      clearTimeout(timeout);
    }
  },
);

function buildSystemPrompt({soilContext, learnedContext, verifiedInsights}) {
  const sections = [
    "You are GardenerGrid AI — an expert assistant specializing in:",
    "- Botany, plant science, horticulture, vegetables, fruit, herbs, flowers, and houseplants",
    "- Organic gardening and sustainable agriculture",
    "- Plant identification, propagation, pruning, and troubleshooting",
    "- Soil science, amendments, and composting",
    "- Companion planting and permaculture design",
    "- Farmers market strategy and local food systems",
    "- Mesh networking for rural agriculture communication",
  ];

  if (soilContext) {
    sections.push(
      "",
      "The user's current soil readings are:",
      `- pH: ${formatNumber(soilContext.ph, 1)}`,
      `- Nitrogen: ${formatNumber(soilContext.nitrogen, 0)} ppm`,
      `- Phosphorus: ${formatNumber(soilContext.phosphorus, 0)} ppm`,
      `- Potassium: ${formatNumber(soilContext.potassium, 0)} ppm`,
      `- Moisture: ${formatNumber(soilContext.moisture, 0)}%`,
      `- Organic Matter: ${formatNumber(soilContext.organicMatter, 1)}%`,
      `- Deficiencies: ${soilContext.deficiencies.length ? soilContext.deficiencies.join(", ") : "None detected"}`,
      `- Health Score: ${soilContext.healthScore ?? "N/A"}/100`,
      `- Source: ${soilContext.source ?? "manual"}`,
      `- Sensor Name: ${soilContext.sensorName ?? "N/A"}`,
      `- Sensor ID: ${soilContext.sensorId ?? "N/A"}`,
      `- Signal Strength: ${soilContext.signalStrength ?? "N/A"}`,
      "Use this data to give personalized soil and plant recommendations.",
    );
  }

  if (learnedContext.length) {
    sections.push(
      "",
      "Known user growing context:",
      ...learnedContext.map((note) => `- ${note}`),
      "Use these details when they are relevant.",
    );
  }

  if (verifiedInsights.length) {
    sections.push(
      "",
      "User-verified lessons from past successful answers:",
      ...verifiedInsights.map((note) => `- ${note}`),
      "Reuse these lessons when they are relevant and consistent with the current question.",
    );
  }

  sections.push(
    "",
    "Guidelines:",
    "- Give practical, actionable advice tailored to the user's context.",
    "- Prefer common plant names first, then include scientific names when useful.",
    "- Be specific about plant care, pests, disease prevention, propagation, and seasonal timing.",
    "- If the question is ambiguous, ask a short clarifying question instead of guessing.",
    "- When discussing foraging, ALWAYS include safety warnings and lookalike hazards.",
    "- Format responses in Markdown with headers, bullet points, and bold text.",
    "- Keep responses concise but thorough — prioritize clarity.",
    "- If the user asks about their specific soil data, always reference the readings provided.",
    "- End advice-oriented answers with a short **Next steps** section.",
    "- For dangerous plant identification questions, emphasize consulting multiple sources.",
  );

  return sections.join("\n");
}

function normalizeHistory(value) {
  if (!Array.isArray(value)) return [];

  return value
    .map((entry) => {
      if (!entry || typeof entry !== "object") return null;
      const role =
        entry.role === "assistant"
          ? "assistant"
          : entry.role === "user"
            ? "user"
            : null;
      const content = clipText(entry.content);
      if (!role || !content) return null;
      return {role, content};
    })
    .filter(Boolean)
    .slice(-MAX_HISTORY_MESSAGES);
}

function normalizeStringList(value, maxItems) {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => clipText(item, 200))
    .filter(Boolean)
    .slice(0, maxItems);
}

function normalizeSoilContext(value) {
  if (!value || typeof value !== "object") return null;

  return {
    ph: toNumber(value.ph),
    nitrogen: toNumber(value.nitrogen),
    phosphorus: toNumber(value.phosphorus),
    potassium: toNumber(value.potassium),
    moisture: toNumber(value.moisture),
    organicMatter: toNumber(value.organicMatter),
    deficiencies: normalizeStringList(value.deficiencies, 12),
    healthScore: Number.isFinite(value.healthScore) ? value.healthScore : null,
    source: readString(value.source, "manual"),
    sensorName: readOptionalString(value.sensorName),
    sensorId: readOptionalString(value.sensorId),
    signalStrength: Number.isFinite(value.signalStrength)
      ? value.signalStrength
      : null,
  };
}

function clipText(value, maxLength = MAX_TEXT_LENGTH) {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  return trimmed.length > maxLength ? trimmed.slice(0, maxLength) : trimmed;
}

function readString(value, fallback) {
  const text = typeof value === "string" ? value.trim() : "";
  return text || fallback;
}

function readOptionalString(value) {
  const text = typeof value === "string" ? value.trim() : "";
  return text || null;
}

function toNumber(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function formatNumber(value, digits) {
  return typeof value === "number" && Number.isFinite(value)
    ? value.toFixed(digits)
    : "N/A";
}
